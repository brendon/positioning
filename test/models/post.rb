class Post < ActiveRecord::Base
  positioned column: :order

  default_scope { order(:order) }
end
