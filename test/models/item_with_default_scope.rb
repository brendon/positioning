class ItemWithDefaultScope < ActiveRecord::Base
  belongs_to :list

  positioned on: :list

  default_scope -> { order(:position) }
end
