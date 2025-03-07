class Category < ActiveRecord::Base
  has_many :categorised_items, dependent: :destroy
  has_many :categorised_items_with_early_positioned, class_name: "CategorisedItemWithEarlyPositioned"

  positioned

  default_scope { order(:position) }
end
