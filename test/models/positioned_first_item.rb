class PositionedFirstItem < ActiveRecord::Base
  positioned on: :list

  belongs_to :list
end
