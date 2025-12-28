module Positioning
  class Mechanisms
    def initialize(positioned, column)
      @positioned = positioned
      @column = column.to_sym
    end

    def prior
      positioning_scope.where(@column => position - 1).first
    end

    def subsequent
      positioning_scope.where(@column => position + 1).first
    end

    def create_position
      lock_positioning_scope!

      solidify_position

      expand(positioning_scope, position..)
    end

    def update_position
      return unless positioning_scope_changed? || position_changed?

      lock_positioning_scope!

      clear_position if positioning_scope_changed? && !position_changed?

      solidify_position
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

    def destroy_position
      unless destroyed_via_positioning_scope?
        lock_positioning_scope!

        move_out_of_the_way
        contract(positioning_scope, (position_was + 1)..)
      end
    end

    private

    def base_class
      @positioned.class.base_class
    end

    def with_connection
      if base_class.respond_to? :with_connection
        base_class.with_connection do |connection|
          yield connection
        end
      else
        yield base_class.connection
      end
    end

    def primary_key
      base_class.primary_key
    end

    def record_scope
      base_class.where primary_key => [@positioned.id]
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
      @position_was ||= record_scope.pick(@column)
    end

    def move_out_of_the_way
      position_was # Memoize the original position before changing it
      update_scope(record_scope, {@column => 0})
    end

    def expand(scope, range)
      update_scope(scope.where(@column => range), {@column => negate_position})
      update_scope(scope.where(@column => ..-1), {@column => negate_position_with_offset(1)})
    end

    def contract(scope, range)
      update_scope(scope.where(@column => range), {@column => negate_position})
      update_scope(scope.where(@column => ..-1), {@column => negate_position_with_offset(-1)})
    end

    def update_scope(scope, updates)
      updates = updates.dup
      updates.merge!(timestamp_updates)
      return if updates.empty?

      manager = Arel::UpdateManager.new
      manager.table(base_class.arel_table)
      manager.set(build_assignments(updates))
      arel_constraints(scope.arel).each { |constraint| manager.where(constraint) }

      with_connection do |connection|
        connection.update(manager, "Positioning update")
      end
    end

    def arel_constraints(arel)
      return arel.constraints if arel.respond_to?(:constraints)

      arel.ast.wheres
    end

    def build_assignments(updates)
      updates.map do |column, value|
        attribute = base_class.arel_table[column]
        unless value.is_a?(Arel::Nodes::Node) || value.is_a?(Arel::Attributes::Attribute)
          value = Arel::Nodes.build_quoted(value, attribute)
        end
        [attribute, value]
      end
    end

    def position_attribute
      base_class.arel_table[@column]
    end

    def negate_position
      Arel::Nodes::Multiplication.new(position_attribute, Arel::Nodes.build_quoted(-1, position_attribute))
    end

    def negate_position_with_offset(offset)
      base = negate_position
      return base if offset.zero?

      adjustment = Arel::Nodes.build_quoted(offset.abs, position_attribute)
      offset.positive? ? Arel::Nodes::Addition.new(base, adjustment) : Arel::Nodes::Subtraction.new(base, adjustment)
    end

    def timestamp_updates
      columns = timestamp_columns
      return {} if columns.empty?

      time = current_time
      columns.each_with_object({}) { |column, updates| updates[column] = time }
    end

    def timestamp_columns
      return [] unless base_class.record_timestamps

      if base_class.respond_to?(:timestamp_attributes_for_update_in_model, true)
        base_class.send(:timestamp_attributes_for_update_in_model)
      else
        base_class.send(:timestamp_attributes_for_update)
      end
    end

    def current_time
      if base_class.respond_to?(:current_time_from_proper_timezone, true)
        base_class.send(:current_time_from_proper_timezone)
      else
        Time.now
      end
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
        relative_position, relative_record_or_id = *position_before_type_cast.first

        unless [:before, :after].include? relative_position
          raise Error.new, "relative `#{@column}` must be either :before, :after"
        end

        relative_id = if relative_record_or_id.is_a? base_class
          relative_record_or_id.id
        else
          relative_record_or_id
        end

        relative_record_scope = positioning_scope.where(primary_key => [relative_id])

        unless relative_record_scope.exists?
          raise Error.new, "relative `#{@column}` record must be in the same scope"
        end

        solidified_position = relative_record_scope.pick(@column)
        solidified_position += 1 if relative_position == :after
        solidified_position -= 1 if in_positioning_scope? && position_was < solidified_position

        self.position = solidified_position
      else
        raise Error.new,
          %(`#{@column}` must be an Integer, :first, :last, ) +
            %{before: (#{base_class.name}, #{primary_key}, nil, or ""), } +
            %{after: (#{base_class.name}, #{primary_key}, nil or ""), nil or ""}
      end
    end

    def last_position
      (positioning_scope.maximum(@column) || 0) + (in_positioning_scope? ? 0 : 1)
    end

    def scope_columns
      base_class.positioning_columns[@column][:scope_columns]
    end

    def scope_associations
      base_class.positioning_columns[@column][:scope_associations]
    end

    def positioning_scope
      base_class.where @positioned.slice(*scope_columns)
    end

    def lock_positioning_scope!
      if scope_associations.present?
        scope_associations.each do |scope_association|
          if @positioned.persisted? && positioning_scope_changed?
            associated_record = record_scope.first.send(scope_association)
            associated_record.class.base_class.lock.find(associated_record.id) if associated_record
          end

          associated_record = @positioned.send(scope_association)
          associated_record.class.base_class.lock.find(associated_record.id) if associated_record
        end
      else
        if @positioned.persisted? && positioning_scope_changed?
          positioning_scope_was.lock.all.load
        end

        positioning_scope.lock.all.load
      end
    end

    def positioning_scope_was
      base_class.where record_scope.first.slice(*scope_columns)
    end

    def in_positioning_scope?
      @positioned.persisted? && positioning_scope.where(primary_key => [@positioned.id]).exists?
    end

    def positioning_scope_changed?
      scope_columns.any? do |scope_column|
        @positioned.attribute_changed?(scope_column)
      end
    end

    def destroyed_via_positioning_scope?
      @positioned.destroyed_by_association && scope_columns.any? do |scope_column|
        @positioned.destroyed_by_association.foreign_key == scope_column
      end
    end
  end
end
