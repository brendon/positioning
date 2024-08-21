class NewItem < ActiveRecord::Base
  belongs_to :list

  positioned on: :list
  positioned on: :list, column: :other_position, advisory_lock: false
end
