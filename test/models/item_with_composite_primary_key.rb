class ItemWithCompositePrimaryKey < ActiveRecord::Base
  belongs_to :list

  positioned on: :list
end
