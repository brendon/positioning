class Blog < ActiveRecord::Base
  has_many :posts, -> { order(:position) }, dependent: :destroy
  has_many :channels, dependent: :destroy

  positioned on: :enabled

  default_scope { order(:position) }
end
