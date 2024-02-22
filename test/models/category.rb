class Category < ActiveRecord::Base
  has_many :categorised_items, dependent: :destroy

  positioned
end
