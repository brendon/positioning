module Positioning
  class Healer
    def initialize(model, column, order)
      @model = model
      @column = column.to_sym
      @order = order
    end

    def heal
      if positioning_columns.present?
        @model.select(*positioning_columns).distinct.each do |scope_record|
          sequence @model.where(scope_record.slice(*positioning_columns))
        end
      else
        sequence @model
      end
    end

    private

    def positioning_columns
      @model.positioning_columns[@column]
    end

    def sequence(scope)
      scope.reorder(@order).each.with_index(1) do |record, index|
        record.update_columns @column => index
      end
    end
  end
end
