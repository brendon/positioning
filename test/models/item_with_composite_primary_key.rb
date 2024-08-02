class ItemWithCompositePrimaryKey < ActiveRecord::Base
  self.primary_key = [:item_id, :account_id]

  belongs_to :list

  positioned on: :list
end
