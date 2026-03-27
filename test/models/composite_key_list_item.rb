if ActiveRecord.version >= Gem::Version.new("7.2.0")
  class CompositeKeyListItem < ActiveRecord::Base
    belongs_to :composite_key_list, foreign_key: [:shop_id, :composite_key_list_id]

    positioned on: :composite_key_list
  end
end
