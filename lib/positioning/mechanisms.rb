module Positioning
  class Mechanisms
    def initialize(positioned, column)
      @positioned = positioned
      @column = column.to_sym
    end

    def prior
      positioning_scope.where("#{@column}": position - 1).first
    end

    def subsequent
      positioning_scope.where("#{@column}": position + 1).first
    end

    def create_position
      solidify_position

      expand(position..)
    end

    def update_position
      # If we're changing scope but not explicitly setting the position then we set the position
      # to nil so that the item gets placed at the end of the list.
      self.position = nil if positioning_scope_changed? && !position_changed?

      solidify_position

      # The update strategy is to temporarily set our position to 0, then shift everything out of the way of
      # our new desired position before finalising it.
      if positioning_scope_changed? || position_changed?
        record_scope = base_class.where("#{primary_key_column}": primary_key)

        position_was = record_scope.pick(@column)
        record_scope.update_all "#{@column}": 0

        if positioning_scope_changed?
          positioning_scope_was = base_class.where record_scope.first.slice(*positioning_columns)

          positioning_scope_was.where("#{@column}": position_was..).reorder("#{@column}": :asc)
            .update_all "#{@column} = (#{@column} - 1)"

          expand(position..)

          # If the position integer was set to the same as its prior value but the scope has changed then
          # we need to tell Rails that it has changed so that it gets updated from the temporary 0 value.
          position_will_change!
        elsif position_was > position
          expand(position..position_was)
        else
          contract(position_was..position)
        end
      end
    end

    def destroy_position
      contract((position + 1)..) unless destroyed_via_positioning_scope?
    end

    private

    def base_class
      @positioned.class.base_class
    end

    def primary_key_column
      base_class.primary_key
    end

    def primary_key
      @positioned.send primary_key_column
    end

    def position
      @positioned.send @column
    end

    def position=(position)
      @positioned.send :"#{@column}=", position
    end

    def position_changed?
      @positioned.send :"#{@column}_changed?"
    end

    def position_will_change!
      @positioned.send :"#{@column}_will_change!"
    end

    def expand(range)
      positioning_scope.where("#{@column}": range).reorder("#{@column}": :desc)
        .update_all "#{@column} = (#{@column} + 1)"
    end

    def contract(range)
      positioning_scope.where("#{@column}": range).reorder("#{@column}": :asc)
        .update_all "#{@column} = (#{@column} - 1)"
    end

    def solidify_position
      position_before_type_cast = @positioned.read_attribute_before_type_cast @column
      position_before_type_cast.to_sym if position_before_type_cast.is_a? String
      position_before_type_cast.symbolize_keys! if position_before_type_cast.is_a? Hash

      case position_before_type_cast
      when Integer
        self.position = position_before_type_cast.clamp(1..last_position)
      when :first, {after: nil}
        self.position = 1
      when nil, :last, {before: nil}
        self.position = last_position
      when Hash
        relative_position, relative_record_or_primary_key = *position_before_type_cast.first

        unless [:before, :after].include? relative_position
          raise Error.new, "relative `#{@column}` must be either :before, :after"
        end

        relative_primary_key = if relative_record_or_primary_key.is_a? base_class
          relative_record_or_primary_key.send(primary_key_column)
        else
          relative_record_or_primary_key
        end

        relative_record_scope = positioning_scope.where("#{primary_key_column}": relative_primary_key)

        unless relative_record_scope.exists?
          raise Error.new, "relative `#{@column}` record must be in the same scope"
        end

        position_was = base_class.where("#{primary_key_column}": primary_key).pick(@column)

        solidified_position = relative_record_scope.pick(@column)
        solidified_position += 1 if relative_position == :after
        solidified_position -= 1 if in_positioning_scope? && position_was < solidified_position

        self.position = solidified_position
      end

      unless position.is_a? Integer
        raise Error.new,
          "`#{@column}` must be an Integer, :first, :last, before: #{base_class.name}, " \
          "after: #{base_class.name}, or nil"
      end
    end

    def last_position
      (positioning_scope.maximum(@column) || 0) + (in_positioning_scope? ? 0 : 1)
    end

    def positioning_columns
      @positioned.class.positioning_columns[@column]
    end

    def positioning_scope
      @positioned.class.where(
        positioning_columns.to_h { |scope_component|
          [scope_component, @positioned.send(scope_component)]
        }
      ).order(@column)
    end

    def in_positioning_scope?
      @positioned.persisted? && positioning_scope.exists?(primary_key)
    end

    def positioning_scope_changed?
      positioning_columns.any? do |scope_component|
        @positioned.attribute_changed?(scope_component)
      end
    end

    def destroyed_via_positioning_scope?
      @positioned.destroyed_by_association && positioning_columns.any? do |scope_component|
        @positioned.destroyed_by_association.foreign_key == scope_component
      end
    end
  end
end