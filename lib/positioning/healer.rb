module Positioning
  class Healer
    def initialize(model, column)
      @model = model
      @column = column.to_sym
    end

    def heal(order)
      each_scope do |scope|
        sequence scope.reorder(order)
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
        sequence [
          *scope.where(@model.primary_key => ids).unscope(:order).find(ids & scope.ids),
          *scope.where.not(@model.primary_key => ids).reorder(@column)
        ]
      end
    end

    private

    def each_scope(conditions = {})
      if scope_columns.present?
        @model.where(conditions).unscope(:order).reselect(*scope_columns).distinct.each do |scope_record|
          @model.transaction do
            lock_scope(scope_record)
            scope = @model.where(scope_record.slice(*scope_columns))
            last_position = (scope.maximum(@column) || 0) + 1
            scope.update_all(@column => @model.arel_table[@column] - last_position)
            yield @model.where(scope_record.slice(*scope_columns)).unscope(:select)
          end
        end
      else
        @model.transaction do
          @model.all.lock!
          last_position = (@model.maximum(@column) || 0) + 1
          @model.update_all(@column => @model.arel_table[@column] - last_position)
          yield @model.unscope(:select)
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

    def sequence(records)
      records.each.with_index(1) do |record, index|
        record.update_columns @column => index
      end
    end
  end
end
