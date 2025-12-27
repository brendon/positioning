require "test_helper"

class TestOptimisticLocking < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_position_updates_do_not_allow_stale_writes_on_loaded_models
    list = List.create name: "List"
    first_item = list.optimistic_locking_items.create name: "First Item"
    second_item = list.optimistic_locking_items.create name: "Second Item"
    third_item = list.optimistic_locking_items.create name: "Third Item"

    scope = list.optimistic_locking_items.order(:position)
    assert_equal [1, 2, 3], scope.pluck(:position)

    third_item.update! position: 1

    assert_equal [third_item.id, first_item.id, second_item.id], scope.pluck(:id)

    assert_equal 0, OptimisticLockingItem.where(id: first_item.id).pick(:lock_version)

    first_item.update! name: "Updated First Item"

    assert_equal "Updated First Item", OptimisticLockingItem.find(first_item.id).name
  end
end
