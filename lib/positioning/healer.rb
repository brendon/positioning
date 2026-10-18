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
            associated_records = scope_associations.filter_map do |scope_association|
              scope_record.send(scope_association)
            end

            if associated_records.any?
              associated_records.each(&:lock!)
            else
              # Relation#lock! only flags the relation, it doesn't run a query
              @model.where(scope_record.slice(*scope_columns)).lock.ids
            end

            sequence @model.where(scope_record.slice(*scope_columns))
          end
        end
      else
        @model.transaction do
          @model.lock.ids
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

    def sequence(scope)
      scope.unscope(:select).reorder(@order).each.with_index(1) do |record, index|
        record.update_columns @column => index
      end
    end
  end
end
