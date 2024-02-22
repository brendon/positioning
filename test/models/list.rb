class List < ActiveRecord::Base
  has_many :items, dependent: :destroy
  has_many :authors, dependent: :destroy
end
