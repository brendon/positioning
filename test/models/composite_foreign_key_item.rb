class CompositeForeignKeyItem < ActiveRecord::Base
  belongs_to :composite_primary_key_item, foreign_key: [:cpki_item_id, :cpki_account_id]

  positioned on: :composite_primary_key_item
end
