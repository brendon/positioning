class Product < ActiveRecord::Base
  positioned

  default_scope { order(:position) }
end
