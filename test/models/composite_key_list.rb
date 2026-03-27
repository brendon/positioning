if ActiveRecord.version >= Gem::Version.new("7.2.0")
  class CompositeKeyList < ActiveRecord::Base
    self.primary_key = [:shop_id, :id]

    has_many :composite_key_list_items, foreign_key: [:shop_id, :id], dependent: :destroy
  end
end
