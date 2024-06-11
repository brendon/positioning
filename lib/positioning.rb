require_relative "positioning/version"
require_relative "positioning/advisory_lock"
require_relative "positioning/mechanisms"

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
        unless base_class == self # rails 6+ unless base_class?
          raise Error.new "can't be called on an abstract class or STI subclass."
        end

        column = column.to_sym

        if positioning_columns.key? column
          raise Error.new "The column `#{column}` has already been used by the scope `#{positioning_columns[column]}`."
        else
          positioning_columns[column] = Array.wrap(on).map do |scope_component|
            scope_component = scope_component.to_s
            reflection = reflections[scope_component]

            (reflection && reflection.belongs_to?) ? reflection.foreign_key : scope_component
          end

          define_method(:"prior_#{column}") { Mechanisms.new(self, column).prior }
          define_method(:"subsequent_#{column}") { Mechanisms.new(self, column).subsequent }

          redefine_method(:"#{column}=") do |position|
            send :"#{column}_will_change!"
            super(position)
          end

          advisory_lock = AdvisoryLock.new(base_class, column)

          before_create advisory_lock
          before_update advisory_lock
          before_destroy advisory_lock

          before_create { Mechanisms.new(self, column).create_position }
          before_update { Mechanisms.new(self, column).update_position }
          before_destroy { Mechanisms.new(self, column).destroy_position }

          after_commit advisory_lock
          after_rollback advisory_lock
        end
      end
    end
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :include, Positioning::Behaviour
end
