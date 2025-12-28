require "test_helper"

class TestRepositioning < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_reposition_position
    first_list = List.create name: "First List"
    second_list = List.create name: "Second List"

    first_item = first_list.new_items.create name: "First Item"
    second_item = first_list.new_items.create name: "Second Item"
    third_item = first_list.new_items.create name: "Third Item"

    fourth_item = second_list.new_items.create name: "Fourth Item"
    fifth_item = second_list.new_items.create name: "Fifth Item"
    sixth_item = second_list.new_items.create name: "Sixth Item"

    NewItem.update_position_in_order_of!([
      third_item.id,
      second_item.id,
      first_item.id,
      sixth_item.id,
      fifth_item.id,
      fourth_item.id
    ])

    assert_equal [1, 2, 3], [third_item.reload, second_item.reload, first_item.reload].map(&:position)
    assert_equal [1, 2, 3], [sixth_item.reload, fifth_item.reload, fourth_item.reload].map(&:position)
  end

  def test_reposition_position_with_partial_selection
    list = List.create name: "Partial List"

    first_item = list.new_items.create name: "First Item"
    second_item = list.new_items.create name: "Second Item"
    third_item = list.new_items.create name: "Third Item"
    fourth_item = list.new_items.create name: "Fourth Item"
    fifth_item = list.new_items.create name: "Fifth Item"

    NewItem.update_position_in_order_of!([
      fourth_item.id,
      second_item.id
    ])

    assert_equal [1, 2, 3, 4, 5], [first_item.reload, fourth_item.reload, third_item.reload, second_item.reload, fifth_item.reload].map(&:position)
  end

  def test_reposition_position_with_weights
    first_product = Product.create name: "First Product"
    second_product = Product.create name: "Second Product"
    third_product = Product.create name: "Third Product"

    Product.update_position_in_order_of!(
      third_product.id => 0,
      second_product.id => 1,
      first_product.id => 2
    )

    assert_equal [1, 2, 3], [third_product.reload, second_product.reload, first_product.reload].map(&:position)
  end

  def test_reposition_position_with_composite_primary_key
    list = List.create name: "Composite List"

    first_item = list.composite_primary_key_items.create item_id: 1, account_id: 10, name: "First Item"
    second_item = list.composite_primary_key_items.create item_id: 2, account_id: 10, name: "Second Item"
    third_item = list.composite_primary_key_items.create item_id: 3, account_id: 10, name: "Third Item"

    CompositePrimaryKeyItem.update_position_in_order_of!([
      third_item.id,
      second_item.id,
      first_item.id
    ])

    assert_equal [1, 2, 3], [third_item.reload, second_item.reload, first_item.reload].map(&:position)
  end

  def test_reposition_position_on_a_tree
    first_category = Category.create name: "First Category"
    second_category = Category.create name: "Second Category"
    third_category = Category.create name: "Third Category", parent: first_category
    fourth_category = Category.create name: "Fourth Category", parent: second_category
    fifth_category = Category.create name: "Fifth Category", parent: second_category
    sixth_category = Category.create name: "Sixth Category", parent: second_category

    Category.update_position_in_order_of!([
      second_category.id,
      first_category.id,
      third_category.id,
      fifth_category.id,
      fourth_category.id,
      sixth_category.id
    ])

    assert_equal [1, 2, 1], [second_category.reload, first_category.reload, third_category.reload].map(&:position)
    assert_equal [1, 2, 3], [fifth_category.reload, fourth_category.reload, sixth_category.reload].map(&:position)
  end

  def test_reposition_position_with_no_scope
    first_product = Product.create name: "First Product"
    second_product = Product.create name: "Second Product"
    third_product = Product.create name: "Third Product"

    Product.update_position_in_order_of!([third_product.id, second_product.id, first_product.id])

    assert_equal [1, 2, 3], [third_product.reload, second_product.reload, first_product.reload].map(&:position)
  end

  def test_reposition_position_with_default_scope
    first_list = List.create name: "First List"

    first_item = first_list.default_scope_items.create name: "First Item"
    second_item = first_list.default_scope_items.create name: "Second Item"
    third_item = first_list.default_scope_items.create name: "Third Item"

    DefaultScopeItem.update_position_in_order_of!([second_item.id, third_item.id, first_item.id])

    assert_equal [1, 2, 3], [second_item.reload, third_item.reload, first_item.reload].map(&:position)
  end
end
