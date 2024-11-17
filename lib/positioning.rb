require_relative "positioning/version"
require_relative "positioning/mechanisms"
require_relative "positioning/healer"

require "active_support/concern"
require "active_support/lazy_load_hooks"

module Positioning
  class Error < StandardError; end

  RelativePosition = Struct.new(:before, :after, keyword_init: true)

  module Behaviour
    extend ActiveSupport::Concern

    class_methods do
      def positioning_columns
        @positioning_columns ||= {}
      end

      def positioned(on: [], column: :position)
        unless base_class?
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
              positioning_columns[column][:scope_columns] << reflection.foreign_key
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

          before_create { Mechanisms.new(self, column).create_position }
          before_update { Mechanisms.new(self, column).update_position }
          before_destroy { Mechanisms.new(self, column).destroy_position }

          define_singleton_method(:"heal_#{column}_column!") do |order = column|
            Healer.new(self, column, order).heal
          end
        end
      end
    end

    def initialize_dup(other)
      super

      self.class.positioning_columns.keys.each do |positioning_column|
        send :"#{positioning_column}=", nil
      end
    end
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :include, Positioning::Behaviour
end
