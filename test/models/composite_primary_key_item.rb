class CompositePrimaryKeyItem < ActiveRecord::Base
  self.primary_key = [:item_id, :account_id]

  belongs_to :list

  has_many :composite_foreign_key_items, foreign_key: [:cpki_item_id, :cpki_account_id], dependent: :destroy

  positioned on: :list
end
