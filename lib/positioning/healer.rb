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

    def sequence(scope)
      scope.unscope(:select).reorder(@order).each.with_index(1) do |record, index|
        record.update_columns @column => index
      end
    end
  end
end
