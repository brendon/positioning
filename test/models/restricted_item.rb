class RestrictedItem < ActiveRecord::Base
  belongs_to :list

  positioned on: :list

  has_many :restrictions, dependent: :restrict_with_error
end
