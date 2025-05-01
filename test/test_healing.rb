require "test_helper"

class TestHealing < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_heal_position
    first_list = List.create name: "First List"
    second_list = List.create name: "Second List"

    first_item = first_list.new_items.create name: "First Item"
    second_item = first_list.new_items.create name: "Second Item"
    third_item = first_list.new_items.create name: "Third Item"

    fourth_item = second_list.new_items.create name: "Fourth Item"
    fifth_item = second_list.new_items.create name: "Fifth Item"
    sixth_item = second_list.new_items.create name: "Sixth Item"

    first_item.update_columns position: 9
    second_item.update_columns position: nil
    third_item.update_columns position: -42

    fourth_item.update_columns position: 0
    fifth_item.update_columns position: 998
    sixth_item.update_columns position: 800

    NewItem.heal_position_column!

    if ENV["DB"] == "postgresql"
      assert_equal [1, 2, 3], [third_item.reload, first_item.reload, second_item.reload].map(&:position)
    else
      assert_equal [1, 2, 3], [second_item.reload, third_item.reload, first_item.reload].map(&:position)
    end

    assert_equal [1, 2, 3], [fourth_item.reload, sixth_item.reload, fifth_item.reload].map(&:position)

    NewItem.heal_position_column! name: :desc

    assert_equal [1, 2, 3], [third_item.reload, second_item.reload, first_item.reload].map(&:position)
    assert_equal [1, 2, 3], [sixth_item.reload, fourth_item.reload, fifth_item.reload].map(&:position)
  end

  def test_heal_position_on_a_tree
    first_category = Category.create name: "First Category"
    second_category = Category.create name: "Second Category"
    third_category = Category.create name: "Third Category", parent: first_category
    fourth_category = Category.create name: "Fourth Category", parent: second_category
    fifth_category = Category.create name: "Fifth Category", parent: second_category
    sixth_category = Category.create name: "Sixth Category", parent: second_category

    first_category.update_columns position: 9
    second_category.update_columns position: 0
    third_category.update_columns position: -42
    fourth_category.update_columns position: 998
    fifth_category.update_columns position: 800
    sixth_category.update_columns position: 1000

    Category.heal_position_column!

    assert_equal [1, 2, 1], [second_category.reload, first_category.reload, third_category.reload].map(&:position)
    assert_equal [1, 2, 3], [fifth_category.reload, fourth_category.reload, sixth_category.reload].map(&:position)
  end

  def test_heal_position_with_no_scope
    first_product = Product.create name: "First Product"
    second_product = Product.create name: "Second Product"
    third_product = Product.create name: "Third Product"

    first_product.update_columns position: 9
    second_product.update_columns position: 0
    third_product.update_columns position: -42

    Product.heal_position_column!

    assert_equal [1, 2, 3], [third_product.reload, second_product.reload, first_product.reload].map(&:position)
  end

  def test_heal_position_with_default_scope
    first_list = List.create name: "First List"

    first_item = first_list.default_scope_items.create name: "First Item"
    second_item = first_list.default_scope_items.create name: "Second Item"
    third_item = first_list.default_scope_items.create name: "Third Item"

    first_item.update_columns position: 10
    second_item.update_columns position: 15
    third_item.update_columns position: 5

    DefaultScopeItem.heal_position_column!

    assert_equal [1, 2, 3], [third_item.reload, first_item.reload, second_item.reload].map(&:position)
  end
end
