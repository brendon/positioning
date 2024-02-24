class List < ActiveRecord::Base
  has_many :items, -> { order(:position) }, dependent: :destroy
  has_many :authors, dependent: :destroy
end
