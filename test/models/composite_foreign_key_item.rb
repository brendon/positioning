class CompositeForeignKeyItem < ActiveRecord::Base
  belongs_to :list, class_name: "CompositePrimaryKeyItem", foreign_key: [:cpki_item_id, :cpki_account_id]

  positioned on: :list
end
