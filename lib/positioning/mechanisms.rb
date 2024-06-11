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

      expand(positioning_scope, position..)
    end

    def update_position
      clear_position if positioning_scope_changed? && !position_changed?

      solidify_position

      if positioning_scope_changed? || position_changed?
        move_out_of_the_way

        if positioning_scope_changed?
          contract(positioning_scope_was, position_was..)
          expand(positioning_scope, position..)
        elsif position_was > position
          expand(positioning_scope, position..position_was)
        else
          contract(positioning_scope, position_was..position)
        end
      end
    end

    def destroy_position
      unless destroyed_via_positioning_scope?
        move_out_of_the_way
        contract(positioning_scope, (position_was + 1)..)
      end
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

    def quoted_column
      base_class.connection.quote_table_name_for_assignment base_class.table_name, @column
    end

    def record_scope
      base_class.where("#{primary_key_column}": primary_key)
    end

    def position
      @positioned.send @column
    end

    def position=(position)
      @positioned.send :"#{@column}=", position
    end

    def clear_position
      self.position = nil
    end

    def position_changed?
      @positioned.send :"#{@column}_changed?"
    end

    def position_was
      @position_was ||= record_scope.limit(1).pluck(@column).first # .pick(@column)
    end

    def move_out_of_the_way
      position_was # Memoize the original position before changing it
      record_scope.update_all "#{@column}": 0
    end

    def expand(scope, range)
      # scope.where("#{@column}": range).update_all "#{quoted_column} = #{quoted_column} * -1"
      # scope.where("#{@column}": ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 + 1"

      if range.end.nil? # This branch for rails < 6
        scope.where("#{quoted_column} >= ?", range.begin).update_all "#{quoted_column} = #{quoted_column} * -1"
      else
        scope.where("#{@column}": range).update_all "#{quoted_column} = #{quoted_column} * -1"
      end

      scope.where("#{quoted_column} <= ?", -1).update_all "#{quoted_column} = #{quoted_column} * -1 + 1"
    end

    def contract(scope, range)
      # scope.where("#{@column}": range).update_all "#{quoted_column} = #{quoted_column} * -1"
      # scope.where("#{@column}": ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 - 1"

      if range.end.nil? # This branch for rails < 6
        scope.where("#{quoted_column} >= ?", range.begin).update_all "#{quoted_column} = #{quoted_column} * -1"
      else
        scope.where("#{@column}": range).update_all "#{quoted_column} = #{quoted_column} * -1"
      end

      scope.where("#{quoted_column} <= ?", -1).update_all "#{quoted_column} = #{quoted_column} * -1 - 1"
    end

    def solidify_position
      position_before_type_cast = @positioned.read_attribute_before_type_cast(@column)

      if position_before_type_cast.is_a? String
        begin
          position_before_type_cast = JSON.parse(position_before_type_cast, symbolize_names: true)
        rescue JSON::ParserError
        end

        if position_before_type_cast.is_a?(String) && position_before_type_cast.present?
          position_before_type_cast = position_before_type_cast.to_sym
        end
      elsif position_before_type_cast.is_a? Hash
        position_before_type_cast = position_before_type_cast.symbolize_keys
      end

      case position_before_type_cast
      when Integer
        self.position = position_before_type_cast.clamp(1..last_position)
      when :first, {after: nil}, {after: ""}
        self.position = 1
      when nil, "", :last, {before: nil}, {before: ""}
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

        solidified_position = relative_record_scope.limit(1).pluck(@column).first # .pick(@column)
        solidified_position += 1 if relative_position == :after
        solidified_position -= 1 if in_positioning_scope? && position_was < solidified_position

        self.position = solidified_position
      end

      unless position.is_a? Integer
        raise Error.new,
          %(`#{@column}` must be an Integer, :first, :last, ) +
            %{before: (#{base_class.name}, #{primary_key_column}, nil, or ""), } +
            %{after: (#{base_class.name}, #{primary_key_column}, nil or ""), nil or ""}
      end
    end

    def last_position
      (positioning_scope.maximum(@column) || 0) + (in_positioning_scope? ? 0 : 1)
    end

    def positioning_columns
      base_class.positioning_columns[@column]
    end

    def positioning_scope
      base_class.where @positioned.slice(*positioning_columns)
    end

    def positioning_scope_was
      base_class.where record_scope.first.slice(*positioning_columns)
    end

    def in_positioning_scope?
      @positioned.persisted? && positioning_scope.where("#{primary_key_column}": primary_key).exists?
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
