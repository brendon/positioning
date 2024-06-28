class List < ActiveRecord::Base
  has_many :items, -> { order(:position) }, dependent: :destroy
  has_many :item_without_advisory_locks, -> { order(:position) }, dependent: :destroy
  has_many :authors, -> { order(:position) }, dependent: :destroy
end
