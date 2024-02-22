class Author < ActiveRecord::Base
  belongs_to :list

  positioned on: [:list, :enabled]
end
