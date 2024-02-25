require "test_helper"

require_relative "models/list"
require_relative "models/item"
require_relative "models/category"
require_relative "models/categorised_item"
require_relative "models/author"
require_relative "models/author/student"
require_relative "models/author/teacher"

class TestPositioningScopes < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::Positioning::VERSION
  end

  def test_that_position_columns_starts_empty
    assert_equal({}, List.positioning_columns)
  end

  def test_that_position_columns_has_default_column
    assert_equal({position: ["list_id"]}, Item.positioning_columns)
  end

  def test_that_position_columns_does_not_need_a_scope
    assert_equal({position: []}, Category.positioning_columns)
  end

  def test_that_position_columns_can_have_multiple_entries
    assert_equal({position: ["list_id"], category_position: ["list_id", "category_id"]}, CategorisedItem.positioning_columns)
  end

  def test_that_position_columns_will_cope_with_standard_columns
    assert_equal({position: ["list_id", "enabled"]}, Author.positioning_columns)
  end

  def test_that_position_columns_must_have_unique_keys
    assert_raises(Positioning::Error) do
      Item.send :positioned, on: :list
    end
  end

  def test_that_the_default_list_scope_works
    list = List.create name: "First List"
    first_item = list.items.create name: "First Item"
    second_item = list.items.create name: "Second Item"
    third_item = list.items.create name: "Third Item"

    assert_equal [first_item, second_item, third_item],
      Positioning::Mechanisms.new(second_item, :position).send(:positioning_scope)
  end

  def test_that_position_will_always_change_on_scope_change
    first_list = List.create name: "First List"
    second_list = List.create name: "Second List"
    first_item = first_list.items.create name: "First Item"

    first_item.update list: second_list
    first_item.reload

    assert_equal 1, first_item.position
  end

  def test_that_destroyed_via_positioning_scope_does_not_call_contract
    list = List.create name: "First List"
    list.items.create name: "First Item"
    list.items.create name: "Second Item"
    list.items.create name: "Third Item"

    Positioning::Mechanisms.any_instance.expects(:contract).never

    list.destroy
  end

  def test_that_not_destroyed_via_positioning_scope_calls_contract
    list = List.create name: "First List"
    list.items.create name: "First Item"
    second_item = list.items.create name: "Second Item"
    list.items.create name: "Third Item"

    Positioning::Mechanisms.any_instance.expects(:contract).once

    second_item.destroy
  end

  def test_that_not_destroyed_via_positioning_scope_closes_gap
    list = List.create name: "First List"
    first_item = list.items.create name: "First Item"
    second_item = list.items.create name: "Second Item"
    third_item = list.items.create name: "Third Item"

    second_item.destroy

    assert_equal [1, 2], [first_item.reload, third_item.reload].map(&:position)
  end
end

class TestPositioning < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def setup
    @first_list = List.create name: "First List"
    @second_list = List.create name: "Second List"
    @first_item = @first_list.items.create name: "First Item"
    @second_item = @first_list.items.create name: "Second Item"
    @third_item = @first_list.items.create name: "Third Item"
    @fourth_item = @second_list.items.create name: "Fourth Item"
    @fifth_item = @second_list.items.create name: "Fifth Item"
    @sixth_item = @second_list.items.create name: "Sixth Item"

    @models = [
      @first_list, @second_list, @first_item, @second_item,
      @third_item, @fourth_item, @fifth_item, @sixth_item
    ]

    reload_models
  end

  def reload_models
    @models.map(&:reload)
  end

  def test_that_updating_an_item_does_not_change_its_position
    @second_item.update name: "Focus Item"
    reload_models

    assert_equal [1, 2, 3], [@first_item, @second_item, @third_item].map(&:position)
  end

  def test_that_prior_item_is_found
    assert_nil @first_item.prior_position
    assert_equal @first_item, @second_item.prior_position
    assert_equal @second_item, @third_item.prior_position
  end

  def test_that_subsequent_item_is_found
    assert_equal @second_item, @first_item.subsequent_position
    assert_equal @third_item, @second_item.subsequent_position
    assert_nil @third_item.subsequent_position
  end

  def test_that_positions_are_automatically_assigned
    assert_equal [1, 2, 3], [@first_item, @second_item, @third_item].map(&:position)
    assert_equal [1, 2, 3], [@fourth_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_an_item_is_added_to_the_end_of_a_new_scope_by_default
    @second_item.update list: @second_list
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @fifth_item, @sixth_item, @second_item].map(&:position)
  end

  def test_that_position_is_assignable_on_create
    seventh_item = @first_list.items.create name: "Seventh Item", position: 2
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, seventh_item, @second_item, @third_item].map(&:position)
  end

  def test_that_position_is_assignable_on_update
    @first_item.update position: 2
    reload_models

    assert_equal [1, 2, 3], [@second_item, @first_item, @third_item].map(&:position)
  end

  def test_that_position_is_assignable_on_update_in_new_scope
    @first_item.update list: @second_list, position: 2
    reload_models

    assert_equal [1, 2], [@second_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @first_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_item_position_is_clamped_up_to_1_on_create
    seventh_item = @first_list.items.create name: "Seventh Item", position: 0
    reload_models

    assert_equal [1, 2, 3, 4], [seventh_item, @first_item, @second_item, @third_item].map(&:position)
  end

  def test_that_item_position_is_clamped_down_to_max_plus_1_on_create
    seventh_item = @first_list.items.create name: "Seventh Item", position: 100
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, @third_item, seventh_item].map(&:position)
  end

  def test_that_item_position_is_clamped_up_to_1_on_update
    @second_item.update position: 0
    reload_models

    assert_equal [1, 2, 3], [@second_item, @first_item, @third_item].map(&:position)
  end

  def test_that_item_position_is_clamped_down_to_max_plus_1_on_update
    @second_item.update position: 100
    reload_models

    assert_equal [1, 2, 3], [@first_item, @third_item, @second_item].map(&:position)
  end

  def test_that_item_position_is_clamped_up_to_1_on_update_scope
    @second_item.update list: @second_list, position: 0
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@second_item, @fourth_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_item_position_is_clamped_down_to_max_plus_1_on_update_scope
    @second_item.update list: @second_list, position: 100
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @fifth_item, @sixth_item, @second_item].map(&:position)
  end

  def test_that_item_is_at_start_of_list_on_create_with_first
    seventh_item = @first_list.items.create name: "Seventh Item", position: :first
    reload_models

    assert_equal [1, 2, 3, 4], [seventh_item, @first_item, @second_item, @third_item].map(&:position)
  end

  def test_that_item_is_at_start_of_list_on_update_with_first
    @second_item.update position: :first
    reload_models

    assert_equal [1, 2, 3], [@second_item, @first_item, @third_item].map(&:position)
  end

  def test_that_item_is_at_end_of_list_on_create_with_last
    seventh_item = @first_list.items.create name: "Seventh Item", position: :last
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, @third_item, seventh_item].map(&:position)
  end

  def test_that_item_is_at_end_of_list_on_update_with_last
    @second_item.update position: :last
    reload_models

    assert_equal [1, 2, 3], [@first_item, @third_item, @second_item].map(&:position)
  end

  def test_that_item_is_at_end_of_list_on_create_with_nil
    seventh_item = @first_list.items.create name: "Seventh Item", position: nil
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, @third_item, seventh_item].map(&:position)
  end

  def test_that_item_is_at_end_of_list_on_update_with_nil
    @second_item.update position: nil
    reload_models

    assert_equal [1, 2, 3], [@first_item, @third_item, @second_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_before
    seventh_item = @first_list.items.create name: "Seventh Item", position: {before: @second_item}
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, seventh_item, @second_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_before_id
    seventh_item = @first_list.items.create name: "Seventh Item", position: {before: @second_item.id}
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, seventh_item, @second_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_before_nil
    seventh_item = @first_list.items.create name: "Seventh Item", position: {before: nil}
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, @third_item, seventh_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_after
    seventh_item = @first_list.items.create name: "Seventh Item", position: {after: @second_item}
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, seventh_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_after_id
    seventh_item = @first_list.items.create name: "Seventh Item", position: {after: @second_item.id}
    reload_models

    assert_equal [1, 2, 3, 4], [@first_item, @second_item, seventh_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_create_with_after_nil
    seventh_item = @first_list.items.create name: "Seventh Item", position: {after: nil}
    reload_models

    assert_equal [1, 2, 3, 4], [seventh_item, @first_item, @second_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_before
    @first_item.update position: {before: @third_item}
    reload_models

    assert_equal [1, 2, 3], [@second_item, @first_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_before_id
    @first_item.update position: {before: @third_item.id}
    reload_models

    assert_equal [1, 2, 3], [@second_item, @first_item, @third_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_before_nil
    @first_item.update position: {before: nil}
    reload_models

    assert_equal [1, 2, 3], [@second_item, @third_item, @first_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_after
    @third_item.update position: {after: @first_item}
    reload_models

    assert_equal [1, 2, 3], [@first_item, @third_item, @second_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_after_id
    @third_item.update position: {after: @first_item.id}
    reload_models

    assert_equal [1, 2, 3], [@first_item, @third_item, @second_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_with_after_nil
    @third_item.update position: {after: nil}
    reload_models

    assert_equal [1, 2, 3], [@third_item, @first_item, @second_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_before
    @second_item.update list: @second_list, position: {before: @sixth_item}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @fifth_item, @second_item, @sixth_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_before_id
    @second_item.update list: @second_list, position: {before: @sixth_item.id}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @fifth_item, @second_item, @sixth_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_before_nil
    @second_item.update list: @second_list, position: {before: nil}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @fifth_item, @sixth_item, @second_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_after
    @second_item.update list: @second_list, position: {after: @fourth_item}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @second_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_after_id
    @second_item.update list: @second_list, position: {after: @fourth_item.id}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@fourth_item, @second_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_items_are_moved_out_of_the_way_on_update_scope_with_after_nil
    @second_item.update list: @second_list, position: {after: nil}
    reload_models

    assert_equal [1, 2], [@first_item, @third_item].map(&:position)
    assert_equal [1, 2, 3, 4], [@second_item, @fourth_item, @fifth_item, @sixth_item].map(&:position)
  end

  def test_that_an_item_must_belong_to_the_scope_of_before_on_create
    assert_raises(Positioning::Error) do
      @second_list.items.create name: "Seventh Item", position: {before: @second_item}
    end
  end

  def test_that_an_item_id_must_belong_to_the_scope_of_before_on_create
    assert_raises(Positioning::Error) do
      @second_list.items.create name: "Seventh Item", position: {before: @second_item.id}
    end
  end

  def test_that_an_item_must_belong_to_the_scope_of_after_on_create
    assert_raises(Positioning::Error) do
      @second_list.items.create name: "Seventh Item", position: {after: @first_item}
    end
  end

  def test_that_an_item_id_must_belong_to_the_scope_of_after_on_create
    assert_raises(Positioning::Error) do
      @second_list.items.create name: "Seventh Item", position: {after: @first_item.id}
    end
  end

  def test_that_an_item_must_belong_to_the_scope_of_before_on_update
    assert_raises(Positioning::Error) do
      @fifth_item.update position: {before: @second_item}
    end
  end

  def test_that_an_item_id_must_belong_to_the_scope_of_before_on_update
    assert_raises(Positioning::Error) do
      @fifth_item.update position: {before: @second_item.id}
    end
  end

  def test_that_an_item_must_belong_to_the_scope_of_after_on_update
    assert_raises(Positioning::Error) do
      @fifth_item.update position: {after: @first_item}
    end
  end

  def test_that_an_item_id_must_belong_to_the_scope_of_after_on_update
    assert_raises(Positioning::Error) do
      @fifth_item.update position: {after: @first_item.id}
    end
  end

  def test_that_an_error_is_raised_with_invalid_relative_key
    assert_raises(Positioning::Error) do
      @first_list.items.create name: "Seventh Item", position: {wrong: @second_item.id}
    end

    assert_raises(Positioning::Error) do
      @first_item.update position: {wrong: @second_item.id}
    end
  end

  def test_that_an_error_is_raised_with_invalid_position
    assert_raises(Positioning::Error) do
      @first_list.items.create name: "Seventh Item", position: :other
    end

    assert_raises(Positioning::Error) do
      @first_item.update position: :other
    end
  end
end

class TestNoScopePositioning < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def setup
    @first_category = Category.create name: "First Category"
    @second_category = Category.create name: "Second Category"
    @third_category = Category.create name: "Third Category"

    @models = [
      @first_category, @second_category, @third_category
    ]

    reload_models
  end

  def reload_models
    @models.map(&:reload)
  end

  def test_initial_positioning
    assert_equal [1, 2, 3], [@first_category, @second_category, @third_category].map(&:position)
  end

  def test_absolute_positioning_create
    positions = [1, 2, 3]

    4.times do |position|
      model = Category.create name: "New Category", position: position
      @models.insert position.clamp(1..3) - 1, model
      positions.push positions.length + 1

      reload_models
      assert_equal positions, @models.map(&:position)
    end
  end

  def test_relative_positioning_create
    positions = [1, 2, 3]

    [:before, :after].each do |relative_position|
      [@first_category, @second_category, @third_category, nil].each do |relative_model|
        model = Category.create name: "New Category", position: {"#{relative_position}": relative_model}

        if !relative_model
          if relative_position == :before
            @models.insert @models.length, model
          elsif relative_position == :after
            @models.insert 0, model
          end
        elsif model != relative_model
          if relative_position == :before
            @models.insert @models.index(relative_model), model
          elsif relative_position == :after
            @models.insert @models.index(relative_model) + 1, model
          end
        end

        positions.push positions.length + 1

        reload_models
        assert_equal positions, @models.map(&:position)
      end
    end

    [:first, :last, nil].each do |relative_position|
      model = Category.create name: "New Category", position: relative_position

      case relative_position
      when :first
        @models.insert 0, model
      when :last, nil
        @models.insert @models.length, model
      end

      positions.push positions.length + 1

      reload_models
      assert_equal positions, @models.map(&:position)
    end
  end

  def test_absolute_positioning_update
    4.times do |position|
      [@first_category, @second_category, @third_category].each do |model|
        model.update position: position
        @models.delete_at @models.index(model)
        @models.insert position.clamp(1..3) - 1, model
        reload_models

        assert_equal [1, 2, 3], @models.map(&:position)
      end
    end
  end

  def test_relative_positioning_update
    [:before, :after].each do |relative_position|
      [@first_category, @second_category, @third_category].each do |model|
        [@first_category, @second_category, @third_category, nil].each do |relative_model|
          model.update position: {"#{relative_position}": relative_model}

          if !relative_model
            @models.delete_at @models.index(model)

            if relative_position == :before
              @models.insert @models.length, model
            elsif relative_position == :after
              @models.insert 0, model
            end
          elsif model != relative_model
            @models.delete_at @models.index(model)

            if relative_position == :before
              @models.insert @models.index(relative_model), model
            elsif relative_position == :after
              @models.insert @models.index(relative_model) + 1, model
            end
          end

          reload_models
          assert_equal [1, 2, 3], @models.map(&:position)
        end
      end
    end

    [:first, :last, nil].each do |relative_position|
      [@first_category, @second_category, @third_category].each do |model|
        model.update position: relative_position

        @models.delete_at @models.index(model)

        case relative_position
        when :first
          @models.insert 0, model
        when :last, nil
          @models.insert @models.length, model
        end

        reload_models
        assert_equal [1, 2, 3], @models.map(&:position)
      end
    end
  end

  def test_destruction
    positions = [1, 2, 3]

    [@second_category, @first_category, @third_category].each do |model|
      index = @models.index(model)
      model.destroy

      @models.delete_at index
      positions.pop

      reload_models
      assert_equal positions, @models.map(&:position)
    end
  end
end

class TestSTIPositioning < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def setup
    @first_list = List.create name: "First List"
    @second_list = List.create name: "Second List"

    @first_student = @first_list.authors.create name: "First Student", type: "Author::Student"
    @first_teacher = @first_list.authors.create name: "First Teacher", type: "Author::Teacher"
    @second_student = @first_list.authors.create name: "Second Student", type: "Author::Student"
    @second_teacher = @first_list.authors.create name: "Second Teacher", type: "Author::Teacher"
    @third_student = @first_list.authors.create name: "Third Student", type: "Author::Student"
    @third_teacher = @first_list.authors.create name: "Third Teacher", type: "Author::Teacher"
    @fourth_student = @second_list.authors.create name: "Fourth Student", type: "Author::Student"
    @fourth_teacher = @second_list.authors.create name: "Fourth Teacher", type: "Author::Teacher"
    @fifth_student = @second_list.authors.create name: "Fifth Student", type: "Author::Student"
    @fifth_teacher = @second_list.authors.create name: "Fifth Teacher", type: "Author::Teacher"
    @sixth_student = @second_list.authors.create name: "Sixth Student", type: "Author::Student"
    @sixth_teacher = @second_list.authors.create name: "Sixth Teacher", type: "Author::Teacher"

    @models = [
      @first_student, @second_student, @third_student,
      @fourth_student, @fifth_student, @sixth_student,
      @first_teacher, @second_teacher, @third_teacher,
      @fourth_teacher, @fifth_teacher, @sixth_teacher
    ]

    reload_models
  end

  def reload_models
    @models.map(&:reload)
  end

  def test_initial_positioning
    assert_equal [1, 2, 3, 4, 5, 6], [
      @first_student, @first_teacher, @second_student,
      @second_teacher, @third_student, @third_teacher
    ].map(&:position)

    assert_equal [1, 2, 3, 4, 5, 6], [
      @fourth_student, @fourth_teacher, @fifth_student,
      @fifth_teacher, @sixth_student, @sixth_teacher
    ].map(&:position)
  end
end
