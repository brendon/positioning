module Positioning
  class Mechanisms
    def initialize(positioned, column)
      @positioned = positioned
      @column = column.to_sym
    end

    def prior
      positioning_scope.where(@column => position - 1).first unless position.nil?
    end

    def subsequent
      positioning_scope.where(@column => position + 1).first unless position.nil?
    end

    def create_position
      lock_positioning_scope!

      clear_position unless position_changed?

      solidify_position

      expand(positioning_scope, position..)
    end

    def update_position
      return unless positioning_scope_changed? || position_changed?

      lock_positioning_scope!
      position_was = self.position_was

      clear_position if positioning_scope_changed? && !position_changed?

      solidify_position

      return forget_position_change if staying_put?

      move_out_of_the_way

      if position_was.nil?
        expand(positioning_scope, position..)
      elsif positioning_scope_changed?
        contract(positioning_scope_was, position_was..)
        expand(positioning_scope, position..)
      elsif position_was > position
        expand(positioning_scope, position..position_was)
      else
        contract(positioning_scope, position_was..position)
      end
    end

    def destroy_position
      return yield if destroyed_via_positioning_scope?

      lock_positioning_scope!
      position_was = self.position_was
      positioning_scope = self.positioning_scope

      if yield
        move_out_of_the_way
        contract(positioning_scope, (position_was + 1)..) unless position_was.nil?
      end
    end

    def lock_positioning_scope!
      record_in_database = record_scope.first if @positioned.persisted? && positioning_scope_changed?
      scopes_to_lock = [record_in_database, @positioned].compact.map { |record| [scope_of(record), parent_rows_of(record)] }
      @snapshot_may_be_stale = base_class.with_connection { |connection| Snapshot.may_be_stale?(connection) }

      scopes_to_lock.each { |scope, parent_rows| lock_scope scope, parent_rows }
    end

    private

    def base_class
      @positioned.class.base_class
    end

    def primary_key
      base_class.primary_key
    end

    def quoted_column
      base_class.with_connection do |connection|
        connection.quote_table_name_for_assignment base_class.table_name, @column
      end
    end

    def record_scope
      base_class.unscoped.where primary_key => [@positioned.id_in_database]
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
      return @position_was if defined?(@position_was)

      @position_was = current(record_scope).pick(@column)
    end

    def staying_put?
      !positioning_scope_changed? && position == position_was
    end

    def forget_position_change
      @positioned.clear_attribute_changes [@column]
    end

    def move_out_of_the_way
      record_scope.update_all @column => 0
    end

    def expand(scope, range)
      if scope.where(@column => range).update_all("#{quoted_column} = #{quoted_column} * -1").positive?
        scope.where(@column => ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 + 1"
      end
    end

    def contract(scope, range)
      if scope.where(@column => range).update_all("#{quoted_column} = #{quoted_column} * -1").positive?
        scope.where(@column => ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 - 1"
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
        self.position = clamped(position_before_type_cast)
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
        relative_record_scope = current(relative_record_scope) if moved_since_snapshot?(relative_record_scope, relative_id)

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

    def clamped(requested_position)
      if snapshot_may_be_stale?
        return 1 if requested_position <= 1
        return requested_position if current(positioning_scope.where(@column => requested_position)).exists?
      end

      requested_position.clamp(1..last_position)
    end

    def last_position
      (end_of_list || 0) + (in_positioning_scope? ? 0 : 1)
    end

    def end_of_list
      return positioning_scope.maximum(@column) unless snapshot_may_be_stale?

      current(positioning_scope).reorder(@column => :desc).pick(@column)
    end

    def scope_columns
      base_class.positioning_columns[@column][:scope_columns]
    end

    def scope_associations
      base_class.positioning_columns[@column][:scope_associations]
    end

    def positioning_scope
      scope_of @positioned
    end

    def lock_scope(scope, parent_rows)
      locked_parent_ids = parent_rows.flat_map { |parent_row| parent_row.lock.ids }

      scope.reorder(primary_key).lock.ids if locked_parent_ids.empty?
    end

    def parent_rows_of(record)
      scope_associations.filter_map do |scope_association|
        association = record.association(scope_association)
        parent_class = association.klass
        foreign_key = Array(association.reflection.foreign_key).map { |column| record[column] }
        next if parent_class.nil? || foreign_key.any?(&:nil?)

        parent_primary_key = Array(association.reflection.association_primary_key(parent_class))
        parent_class.base_class.unscoped.where(parent_primary_key.zip(foreign_key).to_h)
      end
    end

    def snapshot_may_be_stale?
      @snapshot_may_be_stale
    end

    def current(relation)
      snapshot_may_be_stale? ? relation.lock("LOCK IN SHARE MODE") : relation
    end

    def moved_since_snapshot?(relative_record_scope, relative_id)
      return false unless snapshot_may_be_stale?

      position_in_snapshot = relative_record_scope.pick(@column)
      return true if position_in_snapshot.nil?

      index_entry = base_class.unscoped.where(@positioned.slice(*scope_columns)).where(@column => position_in_snapshot)
      Array(current(index_entry).pick(primary_key)).map(&:to_s) != Array(relative_id).map(&:to_s)
    end

    def positioning_scope_was
      scope_of current(record_scope).first
    end

    def scope_of(record)
      base_class.where record.slice(*scope_columns)
    end

    def in_positioning_scope?
      @positioned.persisted? &&
        current(positioning_scope.where(primary_key => [@positioned.id_in_database]).where.not(@column => nil)).exists?
    end

    def positioning_scope_changed?
      scope_columns.any? do |scope_column|
        @positioned.attribute_changed?(scope_column)
      end
    end

    def destroyed_via_positioning_scope?
      @positioned.destroyed_by_association && scope_columns.any? do |scope_column|
        Array(@positioned.destroyed_by_association.foreign_key).include?(scope_column)
      end
    end
  end
end
