require_relative "positioning/version"
require_relative "positioning/mechanisms"
require_relative "positioning/healer"

require "active_support/concern"
require "active_support/lazy_load_hooks"

module Positioning
  class Error < StandardError; end

  RelativePosition = Struct.new(:before, :after, keyword_init: true)

  # Under MySQL's default REPEATABLE READ, a transaction's first plain read fixes the snapshot that its later reads
  # see. Validations, callbacks and attribute assignment can all read before we lock the scope, which would hide
  # changes committed while we waited for the lock. So a save that begins its own transaction runs at READ COMMITTED.
  # An open transaction's level can't be changed (Rails opens one around `association.create`, for example), so a save
  # that joins one takes the lock before anything else in the save can read.
  module Isolation
    def self.mysql?(connection)
      connection.adapter_name.match?(/mysql|trilogy/i)
    end

    def self.level_for(model, connection)
      return if connection.transaction_open? || !mysql?(connection)

      # The app chose a level for this block with ActiveRecord.with_transaction_isolation_level (Rails 8.1+)
      return if ActiveRecord.try(:default_transaction_isolation_level)

      model.positioning_isolation
    end

    def with_transaction_returning_status
      self.class.connection_pool.with_connection do |connection|
        level = Isolation.level_for(self.class, connection)
        next super unless level

        status = nil
        connection.transaction(isolation: level) do
          status = super()
          # Joining swallows the inner ActiveRecord::Rollback, so the real transaction needs telling too
          raise ActiveRecord::Rollback unless status
        end
        status
      end
    end

    def save(**)
      lock_if_joining(:lock_for_save) { super }
    end

    def save!(**)
      lock_if_joining(:lock_for_save) { super }
    end

    def destroy
      lock_if_joining(:lock_for_destroy) { super }
    end

    private

    def lock_if_joining(lock)
      self.class.connection_pool.with_connection do |connection|
        if connection.transaction_open? && Isolation.mysql?(connection)
          self.class.base_class.positioning_columns.each_key do |column|
            Mechanisms.new(self, column).send(lock)
          end
        end

        yield
      end
    end
  end

  module Behaviour
    extend ActiveSupport::Concern

    included do
      class_attribute :positioning_isolation, instance_accessor: false, instance_predicate: false,
        default: :read_committed
    end

    class_methods do
      def positioning_columns
        @positioning_columns ||= {}
      end

      def positioned(on: [], column: :position)
        if abstract_class? || !base_class?
          raise Error.new "can't be called on an abstract class or STI subclass."
        end

        column = column.to_sym

        if positioning_columns.key? column
          raise Error.new "The column `#{column}` has already been used by the scope `#{positioning_columns[column]}`."
        else
          positioning_columns[column] = {scope_columns: [], scope_associations: []}

          Array.wrap(on).each do |scope_component|
            scope_component = scope_component.to_s
            reflection = reflections[scope_component]

            if reflection&.belongs_to?
              positioning_columns[column][:scope_columns].concat Array(reflection.foreign_key)
              positioning_columns[column][:scope_columns] << reflection.foreign_type if reflection.polymorphic?
              positioning_columns[column][:scope_associations] << reflection.name
            else
              positioning_columns[column][:scope_columns] << scope_component
            end
          end

          define_method(:"prior_#{column}") { Mechanisms.new(self, column).prior }
          define_method(:"subsequent_#{column}") { Mechanisms.new(self, column).subsequent }

          redefine_method(:"#{column}=") do |position|
            send :"#{column}_will_change!"
            super(position)
          end

          include Isolation

          before_create { Mechanisms.new(self, column).create_position }
          before_update { Mechanisms.new(self, column).update_position }
          before_destroy { Mechanisms.new(self, column).destroy_position }

          define_singleton_method(:"heal_#{column}_column!") do |order = column|
            Healer.new(base_class, column, order).heal
          end
        end
      end
    end

    def initialize_dup(other)
      super

      self.class.base_class.positioning_columns.keys.each do |positioning_column|
        send :"#{positioning_column}=", nil
      end
    end
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :include, Positioning::Behaviour
end
