require "test_helper"

require_relative "models/list"
require_relative "models/item"
require_relative "models/category"
require_relative "models/categorised_item"
require_relative "models/author"
require_relative "models/author/student"
require_relative "models/author/teacher"
require_relative "models/post"

class TestRelativePositionStruct < Minitest::Test
  def test_struct_takes_keyword_arguments
    relative_position = Positioning::RelativePosition.new(before: 1)
    assert_equal 1, relative_position.before
    assert_nil relative_position.after

    relative_position = Positioning::RelativePosition.new(after: 1)
    assert_equal 1, relative_position.after
    assert_nil relative_position.before

    relative_position = Positioning::RelativePosition.new(before: 2, after: 1)
    assert_equal 2, relative_position.before
    assert_equal 1, relative_position.after
  end
end

class TestTransactionSafety < Minitest::Test
  def test_no_duplicate_row_values
    ActiveRecord::Base.connection_handler.clear_all_connections!

    list = List.create name: "List"
    students = []

    10.times do
      threads = 20.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            students << list.authors.create(name: "Student", type: "Author::Student")
          end
        end
      end
      threads.each(&:join)
    end

    assert_equal (1..students.length).to_a, list.authors.map(&:position)

    list.destroy
  end
end

class TestPositioningMechanisms < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_active_record_is_not_polluted
    refute Item.const_defined?(:Mechanisms)
  end

  def test_base_class
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal Author, mechanisms.send(:base_class)

    mechanisms = Positioning::Mechanisms.new(teacher, :position)
    assert_equal Author, mechanisms.send(:base_class)
  end

  def test_primary_key_column
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal "id", mechanisms.send(:primary_key_column)
  end

  def test_primary_key
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal student.id, mechanisms.send(:primary_key)
  end

  def test_record_scope
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal Author.where(id: student.id).to_sql, mechanisms.send(:record_scope).to_sql
  end

  def test_position
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal 1, mechanisms.send(:position)

    mechanisms = Positioning::Mechanisms.new(teacher, :position)
    assert_equal 2, mechanisms.send(:position)
  end

  def test_position=
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    mechanisms.send(:position=, 2)
    assert_equal 2, student.position
  end

  def test_clear_position
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    mechanisms.send(:clear_position)
    assert_nil student.position
  end

  def test_position_changed?
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    student.position = 2
    assert mechanisms.send(:position_changed?)
  end

  def test_position_was
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    student.position = 2

    assert_equal 1, mechanisms.send(:position_was)
    assert mechanisms.instance_variable_defined? :@position_was
  end

  def test_move_out_of_the_way
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    mechanisms.send(:move_out_of_the_way)

    assert_equal 1, mechanisms.send(:position_was)
    assert mechanisms.instance_variable_defined? :@position_was
    assert_equal 0, Author.where(id: student.id).limit(1).pluck(:position).first # .pick(:position)
  end

  def test_expand
    list = List.create name: "List"
    list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)
    mechanisms.send(:expand, list.authors, 2..)
    assert_equal [1, 3, 4], list.authors.pluck(:position)
  end

  def test_contract
    list = List.create name: "List"
    list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)
    Author.where(id: teacher.id).update_all position: 0
    mechanisms.send(:contract, list.authors, 2..)
    assert_equal [0, 1, 2], list.authors.pluck(:position)
  end

  def test_solidify_position_integer
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(student, :position)

    [0, "0", 0.to_json].each do |position|
      student.reload
      student.position = position
      mechanisms.send(:solidify_position)
      assert_equal 1, student.position
    end

    student.reload
    student.position = 2
    mechanisms.send(:solidify_position)
    assert_equal 2, student.position

    [3, "3", 3.to_json].each do |position|
      student.reload
      student.position = position
      mechanisms.send(:solidify_position)
      assert_equal 2, student.position
    end
  end

  def test_solidify_position_first_and_after_nil
    list = List.create name: "List"
    list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)

    [:first, "first", "first".to_json,
      {after: nil}, {after: nil}.to_json,
      {after: ""}, {after: ""}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 1, teacher.position
    end
  end

  def test_solidify_position_nil_last_and_before_nil
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(student, :position)

    [nil, nil.to_json, "", "".to_json,
      :last, "last", "last".to_json,
      {before: nil}, {before: nil}.to_json,
      {before: ""}, {before: ""}.to_json].each do |position|
      student.reload
      student.position = position
      mechanisms.send(:solidify_position)
      assert_equal 2, student.position
    end
  end

  def test_solidify_position_before
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    list.authors.create name: "Teacher", type: "Author::Teacher"
    last_teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)

    [{before: student}, {before: student.id}, {before: student.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 1, teacher.position
    end

    [{before: teacher}, {before: teacher.id}, {before: teacher.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 2, teacher.position
    end

    [{before: last_teacher}, {before: last_teacher.id}, {before: last_teacher.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 3, teacher.position
    end
  end

  def test_solidify_position_after
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    list.authors.create name: "Teacher", type: "Author::Teacher"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    last_teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)

    [{after: student}, {after: student.id}, {after: student.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 2, teacher.position
    end

    [{after: teacher}, {after: teacher.id}, {after: teacher.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 3, teacher.position
    end

    [{after: last_teacher}, {after: last_teacher.id}, {after: last_teacher.id}.to_json].each do |position|
      teacher.reload
      teacher.position = position
      mechanisms.send(:solidify_position)
      assert_equal 4, teacher.position
    end
  end

  def test_solidify_position_before_new_scope
    list = List.create name: "List"
    second_list = List.create name: "List"
    list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    list.authors.create name: "Teacher", type: "Author::Teacher"
    other_teacher = second_list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(other_teacher, :position)

    [{before: teacher}, {before: teacher.id}, {before: teacher.id}.to_json].each do |position|
      other_teacher.reload
      other_teacher.position = position
      other_teacher.list = list
      mechanisms.send(:solidify_position)
      assert_equal 2, other_teacher.position
    end
  end

  def test_solidify_position_after_new_scope
    list = List.create name: "List"
    second_list = List.create name: "List"
    list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"
    list.authors.create name: "Teacher", type: "Author::Teacher"
    other_teacher = second_list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(other_teacher, :position)

    [{after: teacher}, {after: teacher.id}, {after: teacher.id}.to_json].each do |position|
      other_teacher.reload
      other_teacher.position = position
      other_teacher.list = list
      mechanisms.send(:solidify_position)
      assert_equal 3, other_teacher.position
    end
  end

  def test_solidify_position_with_has_with_indifferent_access
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(teacher, :position)

    teacher.position = {before: student}.with_indifferent_access
    mechanisms.send(:solidify_position)
    assert_equal 1, teacher.position
  end

  def test_last_position
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    list.authors.create name: "Student", type: "Author::Student"
    list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal 3, mechanisms.send(:last_position)
  end

  def test_positioning_columns
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal ["list_id", "enabled"], mechanisms.send(:positioning_columns)
  end

  def test_positioning_scope
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert_equal Author.where(list: list, enabled: true).to_sql, mechanisms.send(:positioning_scope).to_sql
  end

  def test_positioning_scope_was
    first_list = List.create name: "List"
    second_list = List.create name: "List"
    student = first_list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    student.list = second_list

    assert_equal Author.where(list: second_list, enabled: true).to_sql, mechanisms.send(:positioning_scope).to_sql

    assert_equal Author.where(list: first_list, enabled: true).to_sql, mechanisms.send(:positioning_scope_was).to_sql
  end

  def test_in_positioning_scope?
    first_list = List.create name: "List"
    second_list = List.create name: "List"
    student = first_list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    assert mechanisms.send(:in_positioning_scope?)

    student.list = second_list
    refute mechanisms.send(:in_positioning_scope?)
  end

  def test_positioning_scope_changed?
    first_list = List.create name: "List"
    second_list = List.create name: "List"
    student = first_list.authors.create name: "Student", type: "Author::Student"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    refute mechanisms.send(:positioning_scope_changed?)

    student.list = second_list
    assert mechanisms.send(:positioning_scope_changed?)
  end

  def test_destroyed_via_positioning_scope?
    list = List.create name: "List"
    student = list.authors.create name: "Student", type: "Author::Student"
    teacher = list.authors.create name: "Teacher", type: "Author::Teacher"

    mechanisms = Positioning::Mechanisms.new(student, :position)
    refute mechanisms.send(:destroyed_via_positioning_scope?)

    mechanisms = Positioning::Mechanisms.new(teacher, :position)
    teacher.destroy
    refute mechanisms.send(:destroyed_via_positioning_scope?)

    list.destroy
    assert mechanisms.send(:destroyed_via_positioning_scope?)
  end
end

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

  def test_that_an_error_is_raised_when_initialising_on_non_base_class
    assert_raises(Positioning::Error) do
      Author::Student.send :positioned
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

class TestPositioningColumns < Minitest::Test
  include Minitest::Hooks

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  def test_that_a_column_named_order_works
    first_post = Post.create name: "First Post"
    second_post = Post.create name: "Second Post"
    third_post = Post.create name: "Third Post"

    assert_equal [1, 2, 3], [first_post.reload, second_post.reload, third_post.reload].map(&:order)

    second_post.update order: {before: first_post}

    assert_equal [1, 2, 3], [second_post.reload, first_post.reload, third_post.reload].map(&:order)

    first_post.update order: {after: third_post}

    assert_equal [1, 2, 3], [second_post.reload, third_post.reload, first_post.reload].map(&:order)

    third_post.destroy

    assert_equal [1, 2], [second_post.reload, first_post.reload].map(&:order)
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

  def test_that_an_item_is_added_to_position_of_a_new_scope_when_explicitly_set
    puts "THIS ONE"
    @second_item.update list: @second_list, position: 2 # NOTE: The same position it already had
    @third_item.update list: @second_list, position: 1
    @first_item.update list: @second_list, position: nil
    reload_models

    assert @first_list.items.empty?
    assert_equal @second_list.items, [@third_item, @fourth_item, @second_item, @fifth_item, @sixth_item, @first_item]
    assert_equal [1, 2, 3, 4, 5, 6], [@third_item, @fourth_item, @second_item, @fifth_item, @sixth_item, @first_item].map(&:position)
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

  def test_destroying_multiple_items
    @first_list.items.limit(2).destroy_all
    @third_item.reload

    assert_equal 1, @third_item.position
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
      assert_equal Category.all, @models
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
        assert_equal Category.all, @models
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
      assert_equal Category.all, @models
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
        assert_equal Category.all, @models
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
          assert_equal Category.all, @models
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
        assert_equal Category.all, @models
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
      assert_equal Category.all, @models
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

    @first_list_models = [
      @first_student, @first_teacher, @second_student,
      @second_teacher, @third_student, @third_teacher
    ]

    @second_list_models = [
      @fourth_student, @fourth_teacher, @fifth_student,
      @fifth_teacher, @sixth_student, @sixth_teacher
    ]

    reload_models
  end

  def reload_models
    [@first_list, @second_list].map(&:reload)
    @first_list_models.map(&:reload)
    @second_list_models.map(&:reload)
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

  def test_absolute_positioning_create
    types = ["Author::Student", "Author::Teacher"].cycle

    [[@first_list, @first_list_models], [@second_list, @second_list_models]].each do |(list, models)|
      positions = [1, 2, 3, 4, 5, 6]

      4.times do |position|
        model = list.authors.create name: "New Author", position: position, type: types.next
        models.insert position.clamp(1..3) - 1, model
        positions.push positions.length + 1

        reload_models
        assert_equal list.authors, models
        assert_equal positions, models.map(&:position)
      end
    end
  end

  def test_relative_positioning_create
    types = ["Author::Student", "Author::Teacher"].cycle

    [[@first_list, @first_list_models], [@second_list, @second_list_models]].each do |(list, models)|
      positions = [1, 2, 3, 4, 5, 6]

      [:before, :after].each do |relative_position|
        [*models.dup, nil].each do |relative_model|
          model = list.authors.create name: "New Author", position: {"#{relative_position}": relative_model},
            type: types.next

          if !relative_model
            if relative_position == :before
              models.insert models.length, model
            elsif relative_position == :after
              models.insert 0, model
            end
          elsif model != relative_model
            if relative_position == :before
              models.insert models.index(relative_model), model
            elsif relative_position == :after
              models.insert models.index(relative_model) + 1, model
            end
          end

          positions.push positions.length + 1

          reload_models
          assert_equal list.authors, models
          assert_equal positions, models.map(&:position)
        end
      end

      [:first, :last, nil].each do |relative_position|
        model = list.authors.create name: "New Author", position: relative_position, type: types.next

        case relative_position
        when :first
          models.insert 0, model
        when :last, nil
          models.insert models.length, model
        end

        positions.push positions.length + 1

        reload_models
        assert_equal list.authors, models
        assert_equal positions, models.map(&:position)
      end
    end
  end

  def test_absolute_positioning_update
    [[@first_list, @first_list_models, @second_list, @second_list_models],
      [@second_list, @second_list_models, @first_list, @first_list_models]]
      .each do |(list, models, other_list, other_models)|
      models.dup.each do |model|
        8.times do |position|
          model.update position: position
          models.delete_at models.index(model)
          models.insert position.clamp(1..6) - 1, model

          reload_models
          assert_equal list.authors, models
          assert_equal [1, 2, 3, 4, 5, 6], models.map(&:position)
        end
      end
    end
  end

  def test_absolute_positioning_update_scope
    positions = [1, 2, 3, 4, 5, 6]
    other_positions = [1, 2, 3, 4, 5, 6]

    [[@first_list, @first_list_models, @second_list, @second_list_models],
      [@second_list, @second_list_models, @first_list, @first_list_models]]
      .each do |(list, models, other_list, other_models)|
      models.dup.each do |model|
        8.times do |position|
          model.update position: position, list: other_list

          models.delete_at models.index(model)
          other_models.insert position.clamp(1..6) - 1, model
          positions.pop
          other_positions.push other_positions.length + 1

          reload_models
          assert_equal list.authors, models
          assert_equal other_list.authors, other_models
          assert_equal positions, models.map(&:position)
          assert_equal other_positions, other_models.map(&:position)

          list, other_list = other_list, list
          models, other_models = other_models, models
          positions, other_positions = other_positions, positions
        end
      end
    end
  end

  def test_relative_positioning_update
    [[@first_list, @first_list_models], [@second_list, @second_list_models]]
      .each do |(list, models)|
      models.dup.each do |model|
        [:before, :after].each do |relative_position|
          [*models.dup, nil].each do |relative_model|
            model.update position: {"#{relative_position}": relative_model}

            if !relative_model
              models.delete_at models.index(model)

              if relative_position == :before
                models.insert models.length, model
              elsif relative_position == :after
                models.insert 0, model
              end
            elsif model != relative_model
              models.delete_at models.index(model)

              if relative_position == :before
                models.insert models.index(relative_model), model
              elsif relative_position == :after
                models.insert models.index(relative_model) + 1, model
              end
            end

            reload_models
            assert_equal list.authors, models
            assert_equal [1, 2, 3, 4, 5, 6], models.map(&:position)
          end
        end

        [:first, :last, nil].each do |relative_position|
          model.update position: relative_position
          models.delete_at models.index(model)

          case relative_position
          when :first
            models.insert 0, model
          when :last, nil
            models.insert models.length, model
          end

          reload_models
          assert_equal list.authors, models
          assert_equal [1, 2, 3, 4, 5, 6], models.map(&:position)
        end
      end
    end
  end

  def test_relative_positioning_update_scope
    positions = [1, 2, 3, 4, 5, 6]
    other_positions = [1, 2, 3, 4, 5, 6]

    [[@first_list, @first_list_models, @second_list, @second_list_models],
      [@second_list, @second_list_models, @first_list, @first_list_models]]
      .each do |(list, models, other_list, other_models)|
      models.dup.each do |model|
        [:before, :after].each do |relative_position|
          other_models.dup.zip(models.dup).flatten.each do |relative_model|
            model.update position: {"#{relative_position}": relative_model}, list: relative_model.list
            list_changed = model.list_id_previously_changed?

            if model != relative_model
              models.delete_at models.index(model)

              if list_changed
                if relative_position == :before
                  other_models.insert other_models.index(relative_model), model
                elsif relative_position == :after
                  other_models.insert other_models.index(relative_model) + 1, model
                end

                positions.pop
                other_positions.push other_positions.length + 1
              elsif relative_position == :before
                models.insert models.index(relative_model), model
              elsif relative_position == :after
                models.insert models.index(relative_model) + 1, model
              end
            end

            reload_models
            assert_equal list.authors, models
            assert_equal other_list.authors, other_models
            assert_equal positions, models.map(&:position)
            assert_equal other_positions, other_models.map(&:position)

            if list_changed
              list, other_list = other_list, list
              models, other_models = other_models, models
              positions, other_positions = other_positions, positions
            end
          end
        end
      end
    end
  end

  def test_relative_positioning_update_scope_relative_nil
    positions = [1, 2, 3, 4, 5, 6]
    other_positions = [1, 2, 3, 4, 5, 6]

    [[@first_list, @first_list_models, @second_list, @second_list_models],
      [@second_list, @second_list_models, @first_list, @first_list_models]]
      .each do |(list, models, other_list, other_models)|
      models.dup.each do |model|
        [:before, :after].each do |relative_position|
          [other_list, list].each do |relative_list|
            model.update position: {"#{relative_position}": nil}, list: relative_list

            models.delete_at models.index(model)

            if relative_position == :before
              other_models.insert other_models.length, model
            elsif relative_position == :after
              other_models.insert 0, model
            end

            positions.pop
            other_positions.push other_positions.length + 1

            reload_models
            assert_equal list.authors, models
            assert_equal other_list.authors, other_models
            assert_equal positions, models.map(&:position)
            assert_equal other_positions, other_models.map(&:position)

            list, other_list = other_list, list
            models, other_models = other_models, models
            positions, other_positions = other_positions, positions
          end
        end

        [:first, :last, nil].each do |relative_position|
          [other_list, list].each do |relative_list|
            model.update position: relative_position, list: relative_list

            models.delete_at models.index(model)

            case relative_position
            when :first
              other_models.insert 0, model
            when :last, nil
              other_models.insert other_models.length, model
            end

            positions.pop
            other_positions.push other_positions.length + 1

            reload_models
            assert_equal list.authors, models
            assert_equal other_list.authors, other_models
            assert_equal positions, models.map(&:position)
            assert_equal other_positions, other_models.map(&:position)

            list, other_list = other_list, list
            models, other_models = other_models, models
            positions, other_positions = other_positions, positions
          end
        end
      end
    end
  end

  def test_destruction
    second_list_models_for_iteration = @second_list_models.slice(0, 3)
      .zip(@second_list_models.slice(3, 3)).flatten

    [[@first_list, @first_list_models, @first_list_models.dup],
      [@second_list, @second_list_models, second_list_models_for_iteration]]
      .each do |(list, models, models_for_iteration)|
      positions = [1, 2, 3, 4, 5, 6]

      models_for_iteration.each do |model|
        index = models.index(model)
        model.destroy

        models.delete_at index
        positions.pop

        reload_models
        assert_equal list.authors, models
        assert_equal positions, models.map(&:position)
      end
    end
  end
end
