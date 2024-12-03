class Post < ActiveRecord::Base
  belongs_to :blog, optional: true

  positioned on: :blog
  positioned column: :order

  default_scope { order(:order) }
end
