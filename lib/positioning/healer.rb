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
            if scope_associations.present?
              scope_associations.each do |scope_association|
                scope_record.send(scope_association)&.lock!
              end
            else
              @model.where(scope_record.slice(*scope_columns)).lock!
            end

            sequence @model.where(scope_record.slice(*scope_columns))
          end
        end
      else
        @model.transaction do
          @model.all.lock!
          sequence @model
        end
      end
    end

    private

    def scope_columns
      @model.positioning_columns[@column][:scope_columns]
    end

    def scope_associations
      @model.positioning_columns[@column][:scope_associations]
    end

    def primary_key
      @model.primary_key
    end

    # Records are first parked on distinct values below anything currently in use (and below 0),
    # then flipped into 1..n in one statement, so a unique index on the position column can't be
    # violated part way through.
    def sequence(scope)
      ids = scope.reorder(@order).order(*Array(primary_key)).pluck(*Array(primary_key))
      return if ids.empty?

      floor = [scope.minimum(@column) || 0, 0].min

      ids.each.with_index(1) do |id, index|
        @model.unscoped.where(primary_key => [id]).update_all @column => floor - index
      end

      scope.update_all @column => Arel::Nodes::Subtraction.new(Arel::Nodes.build_quoted(floor), @model.arel_table[@column])
    end
  end
end
