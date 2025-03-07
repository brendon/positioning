class CategorisedItemWithEarlyPositioned < ActiveRecord::Base
  self.table_name = 'categorised_items'

  belongs_to :list

  positioned on: :list
  positioned on: [:list, :category], column: :category_position

  belongs_to :category
end
