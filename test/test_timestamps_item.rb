require "test_helper"

class TestTimestampsItem < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_updated_at_is_touched_when_other_items_are_repositioned
    list = List.create name: "List"
    first_item = list.timestamps_items.create name: "First Item"
    second_item = list.timestamps_items.create name: "Second Item"
    third_item = list.timestamps_items.create name: "Third Item"

    before_updated_ats = list.timestamps_items.order(:id).pluck(:id, :updated_at).to_h

    third_item.update! position: 1

    after_updated_ats = list.timestamps_items.order(:id).pluck(:id, :updated_at).to_h

    assert_equal [third_item.id, first_item.id, second_item.id],
      list.timestamps_items.order(:position).pluck(:id)
    assert_operator after_updated_ats[first_item.id], :>, before_updated_ats[first_item.id]
    assert_operator after_updated_ats[second_item.id], :>, before_updated_ats[second_item.id]
    assert_operator after_updated_ats[third_item.id], :>, before_updated_ats[third_item.id]
  end
end
