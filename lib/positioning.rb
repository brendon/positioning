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
        return @positioning_columns if @positioning_columns

        resolved = true

        scopes = (@positioning_scopes || {}).transform_values do |scope_components|
          {scope_columns: [], scope_associations: []}.tap do |scope|
            scope_components.each do |scope_component|
              reflection = reflections[scope_component]

              if reflection&.belongs_to?
                scope[:scope_columns].concat Array(reflection.foreign_key)
                scope[:scope_columns] << reflection.foreign_type if reflection.polymorphic?
                scope[:scope_associations] << reflection.name
              else
                # Unless it's a column, it could be a belongs_to that hasn't been declared yet
                resolved &&= column_names.include?(scope_component)
                scope[:scope_columns] << scope_component
              end
            end
          end
        end

        @positioning_columns = scopes if resolved
        scopes
      end

      def positioned(on: [], column: :position)
        if abstract_class? || !base_class?
          raise Error.new "can't be called on an abstract class or STI subclass."
        end

        column = column.to_sym
        @positioning_scopes ||= {}

        if @positioning_scopes.key? column
          raise Error.new "The column `#{column}` has already been used by the scope `#{@positioning_scopes[column]}`."
        else
          @positioning_scopes[column] = Array.wrap(on).map(&:to_s)
          @positioning_columns = nil

          define_method(:"prior_#{column}") { Mechanisms.new(self, column).prior }
          define_method(:"subsequent_#{column}") { Mechanisms.new(self, column).subsequent }

          # Defined in a module so that a writer defined in the model itself can call super to reach it,
          # rather than replacing it (or being replaced by it).
          writer = Module.new do
            define_method(:"#{column}=") do |position|
              attribute_will_change!(column.to_s)
              super(position)
            end
          end

          include writer

          before_create { Mechanisms.new(self, column).create_position }
          before_update { Mechanisms.new(self, column).update_position }
          around_destroy { |positioned, block| Mechanisms.new(positioned, column).destroy_position(&block) }

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
