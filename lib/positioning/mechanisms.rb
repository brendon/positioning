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

      # A column default isn't a requested position. Only an assigned value is.
      clear_position unless position_changed?

      solidify_position

      expand(positioning_scope, position..)
    end

    def update_position
      return unless positioning_scope_changed? || position_changed?

      lock_positioning_scope!

      clear_position if positioning_scope_changed? && !position_changed?

      solidify_position
      move_out_of_the_way

      # A record without a position doesn't occupy a slot, so there's no gap to close
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
      unless destroyed_via_positioning_scope?
        lock_positioning_scope!

        move_out_of_the_way
        contract(positioning_scope, (position_was + 1)..) unless position_was.nil?
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

    def quoted_column
      with_connection do |connection|
        connection.quote_table_name_for_assignment base_class.table_name, @column
      end
    end

    # The record's row as it is in the database, regardless of default scopes or in-memory key changes
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

      @position_was = record_scope.pick(@column)
    end

    def move_out_of_the_way
      position_was # Memoize the original position before changing it
      record_scope.update_all @column => 0
    end

    def expand(scope, range)
      scope.where(@column => range).update_all "#{quoted_column} = #{quoted_column} * -1"
      scope.where(@column => ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 + 1"
    end

    def contract(scope, range)
      scope.where(@column => range).update_all "#{quoted_column} = #{quoted_column} * -1"
      scope.where(@column => ..-1).update_all "#{quoted_column} = #{quoted_column} * -1 - 1"
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
      if @positioned.persisted? && positioning_scope_changed?
        lock_scope scope_columns.index_with { |scope_column| @positioned.attribute_in_database(scope_column) }
      end

      lock_scope @positioned.slice(*scope_columns)
    end

    # Lock by key, without reading anything first. On MySQL a transaction's first plain read fixes its snapshot,
    # which would hide changes committed while we waited for the lock. Default scopes are ignored so that they
    # can't hide a row from the lock or preload anything.
    def lock_scope(scope_attributes)
      if scope_associations.present?
        scope_associations.each do |scope_association|
          reflection = base_class.reflect_on_association(scope_association)
          key = scope_attributes.values_at(*Array(reflection.foreign_key))

          klass = if reflection.polymorphic?
            type = scope_attributes[reflection.foreign_type]
            base_class.polymorphic_class_for(type) if type
          else
            reflection.klass
          end

          if klass && key.none?(&:nil?)
            klass.base_class.unscoped.where(Array(reflection.association_primary_key(klass)).zip(key).to_h).lock.ids
          end
        end
      else
        # Whole rows, as selecting only ids lets MySQL lock through a covering index on the position column. A
        # transaction queued there would block our own position writes into the gap before it, and deadlock.
        base_class.unscoped.where(scope_attributes).lock.all.load
      end
    end

    def positioning_scope_was
      base_class.where record_scope.first.slice(*scope_columns)
    end

    def in_positioning_scope?
      @positioned.persisted? &&
        positioning_scope.where(primary_key => [@positioned.id_in_database]).where.not(@column => nil).exists?
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
