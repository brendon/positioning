class Category < ActiveRecord::Base
  has_many :categorised_items, dependent: :destroy

  positioned

  default_scope { order(:position) }
end
