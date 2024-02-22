class CategorisedItem < ActiveRecord::Base
  belongs_to :list
  belongs_to :category

  positioned on: :list
  positioned on: [:list, :category], column: :category_position
end
