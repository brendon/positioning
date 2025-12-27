class List < ActiveRecord::Base
  has_many :items, -> { order(:position) }, dependent: :destroy
  has_many :optimistic_locking_items, -> { order(:position) }, dependent: :destroy
  has_many :timestamps_items, -> { order(:position) }, dependent: :destroy
  has_many :new_items, -> { order(:position) }, dependent: :destroy
  has_many :default_scope_items, -> { order(:position) }, dependent: :destroy
  has_many :composite_primary_key_items, -> { order(:position) }, dependent: :destroy
  has_many :authors, -> { order(:position) }, dependent: :destroy
end
