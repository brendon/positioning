module Positioning
  class Healer
    def initialize(model, column)
      @model = model
      @column = column.to_sym
    end

    def heal(order)
      each_scope do |scope|
        # Move whole scope out of the way
        last_position = (scope.maximum(@column) || 0) + 1
        scope.update_all(@column => @model.arel_table[@column] - last_position)

        scope.order(order).each.with_index(1) do |record, index|
          record.update_column @column, index
        end
      end
    end

    def reposition(values)
      pk_type = @model.type_for_attribute(@model.primary_key)
      ids = if values.is_a?(Hash)
        pairs = values.to_a.reject { |id, weight| id.nil? || weight.nil? }
        pairs = pairs.each_with_index.map { |(id, weight), index| [id, weight, index] }
        pairs.sort_by! { |(_, weight, index)| [weight, index] }
        pairs.map { |id, _weight, _index| id }
      else
        Array.wrap(values)
      end.map { |id| pk_type.cast(id) }.compact_blank.uniq

      return if ids.empty?

      each_scope(@model.primary_key => ids) do |scope|
        scoped_records = scope.where(@model.primary_key => ids)
        scoped_ids = ids & scoped_records.ids
        positions = scoped_records.pluck(@column).sort

        # Move only selected scope out of the way
        last_position = (positions.max || 0) + 1
        scoped_records.update_all(@column => @model.arel_table[@column] - last_position)

        scoped_records.find(scoped_ids).zip(positions).each do |record, position|
          record.update_column @column, position
        end
      end
    end

    private

    def each_scope(conditions = {})
      if scope_columns.present?
        @model.where(conditions).unscope(:order).reselect(*scope_columns).distinct.each do |scope_record|
          @model.transaction do
            lock_scope(scope_record)
            yield @model.where(scope_record.slice(*scope_columns)).unscope(:order, :select)
          end
        end
      else
        @model.transaction do
          @model.all.lock!
          yield @model.unscope(:order, :select)
        end
      end
    end

    def lock_scope(scope_record)
      if scope_associations.present?
        scope_associations.each do |scope_association|
          scope_record.send(scope_association)&.lock!
        end
      else
        @model.where(scope_record.slice(*scope_columns)).lock!
      end
    end

    def scope_columns
      @model.positioning_columns[@column][:scope_columns]
    end

    def scope_associations
      @model.positioning_columns[@column][:scope_associations]
    end
  end
end
