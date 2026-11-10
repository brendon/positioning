class Category < ActiveRecord::Base
  belongs_to :parent, class_name: "Category", optional: true
  has_many :categorised_items, dependent: :destroy

  positioned on: :parent
end
