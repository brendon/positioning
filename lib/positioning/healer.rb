module Positioning
  class Healer
    def initialize(model, column, order)
      @model = model
      @column = column.to_sym
      @order = order
    end

    def heal
      if scope_columns.present?
        @model.unscope(:order).reselect(*scope_columns).distinct.each do |scope_record|
          @model.transaction do
            Mechanisms.new(scope_record, @column).lock_positioning_scope!
            sequence @model.where(scope_record.slice(*scope_columns))
          end
        end
      else
        @model.transaction do
          @model.reorder(primary_key).lock.ids
          sequence @model
        end
      end
    end

    private

    def scope_columns
      @model.positioning_columns[@column][:scope_columns]
    end

    def primary_key
      @model.primary_key
    end

    def sequence(scope)
      ids = scope.reorder(@order).order(primary_key).pluck(primary_key)
      return if ids.empty?

      floor = [scope.minimum(@column) || 0, 0].min

      ids.each.with_index(1) do |id, index|
        @model.unscoped.where(primary_key => [id]).update_all @column => floor - index
      end

      scope.update_all @column => Arel::Nodes::Subtraction.new(Arel::Nodes.build_quoted(floor), @model.arel_table[@column])
    end
  end
end
