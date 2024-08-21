# Positioning

The aim of this gem is to allow you to easily position Active Record model instances within a scope of your choosing. In an ideal world this gem will give your model instances sequential integer positions beginning with `1`. Attempts are made to make all changes within a transaction so that position integers remain consistent. To this end, directly assigning a position is discouraged, instead you can move items by declaring an item's prior or subsequent item in the list and your item will be moved to be relative to that item.

Positioning supports multiple lists per model with global, simple, and complex scopes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'positioning'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install positioning

## Usage

In the simplest case our database column should be named `position` and not allow `NULL` as a value:

`add_column :items, :position, :integer, null: false`

You should also add an index to ensure that the `position` column value is unique within its scope:

`add_index :items, [:list_id, :position], unique: true`

The above assumes that your items are scoped to a parent table called `lists`.

The Positioning gem uses `0` and negative integers to rearrange the lists it manages so don't add database validations to restrict the usage of these. You are also restricted from using `0` and negative integers as position values. If you try, the position value will become `1`. If you try to set an explicit position value that is greater than the next available list position, it will be rounded down to that value.

### Declaring Positioning

To declare that your model should keep track of the position of its records you can use the `positioned` method. Here are some examples:

```ruby
# The scope is global (all records will belong to the same list) and the database column
# is 'positioned'
positioned

# The scope is on the belongs_to relationship 'list' and the database column is 'positioned'
# We check if the scope is a belongs_to relationship and use its declared foreign_key as
# the scope value. In this case it would be 'list_id' since we haven't overridden the
# default foreign key.
belongs_to :list
positioned on: :list

# If you want to change the database column used to record positions you can do so via the
# ':column' parameter. This is most useful when you are keeping track of more than one
# list on a model.
belongs_to :list
belongs_to :category
positioned on: :list
positioned on: :category, column: :category_position

# A scope need not be a belongs_to relationship; it can be any column in the database table.
positioned on: :type

# Finally, you can have more complex scopes defined as an array of relationships and/or
# columns.
belongs_to :list
belongs_to :category
positioned on: [:list, :category, :enabled]

# If you do not want to use Advisory Lock, you can disable it entirely by passing the 'advisory_lock' flag as false
belongs_to :list
positioned on: :list, advisory_lock: false
```

### Initialising a List

If you are adding `positioning` to a model with existing database records, or you're migrating from another gem like `acts_as_list` or `ranked-model` and have an existing position column, you will need to do some work to ensure you have well formed position values for your records. `positioning` has a helper method per `positioned` declaration that allows you to 'heal' the position column, ensuring that positions are positive integers starting at 1 with no gaps.

For example, in the usual case:

```
belongs_to :list
positioned on: :list
```

you'll have a method called `heal_position_column!`. You can call this method and it will cycle through every existing scope combination in your database (every list with items in this case) and reset those items' position based on their current position order by default. You can pass in a custom order if you don't trust (or don't have) an existing order column. The custom order is passed through to the Active Record `reorder` method, so you can provide anything that that method accepts:

```
Item.heal_position_column! name: :desc
```

You may need to introduce your database constraints after healing your position column:

* We recommend a `null: false` constraint on the position column but if your existing column has `NULL` values, you'll need to fix those first. The heal method will heal `NULL` positions but depending on your database engine `NULL` positioned items might be placed at the start of the returned records or at the end (if positioning on the position column). Some databases allow this behaviour to be customised.
* We also recommend a unique index on the scope columns and the position column. If you have repeated position integers per scope you'll need to use the heal method to fix these first before applying the unique index in a separate migration step.

The heal method name is named after the column used to store position values. By default this is `position` but if you override it then the method name will change:

```
positioned on: :category, column: :category_position
```

will have a class method named `heal_category_position_column!`.

### Manipulating Positioning

The tools for manipulating the position of records in your list have been kept intentionally terse. Priority has also been given to minimal pollution of the model namespace. Only two class methods are defined on all models (`positioning_columns` and `positioned`), and two instance methods are defined on models that call `positioned`:

#### Accessing Relative List Items

The two instance methods that we add are for finding the prior and subsequent items relative to the current item in the list. These methods are named after the database column used to track positioning. By default the methods are named `prior_position` and `subsequent_position`. In the example above where we used the column `category_position` then the methods would be named `prior_category_position` and `subsequent_category_position`.

#### Assigning Positions

If you don't provide a position when creating a record, your record will be added to the end of the list.

To assign a specific position when creating or updating a record you can simply declare a specific value for the database column tracking the position of records (by default this is `position`). The valid options for this column are:

* A specific integer value as an `Integer` or a `String`. Values are automatically clamped to between `1` and the next available position at the end of the list (inclusive). You should use explicit position values as a last resort, instead you can use:
* `:first` or `"first"` places the record at the start of the list.
* `:last` or `"last"` places the record at the end of the list.
* `nil` and `""` also places the record at the end of the list.
* `before:` and `after:` allow you to define the position relative to other records in the list. You can define the relative record by its primary key (usually `id`) or by providing the record itself. You can also provide `nil` or `""` in which case the item will be placed at the start or end of the list (see below).

**You can provide the position value as a JSON string and it will be decoded first. This could be useful if you have no other way to provide `before:` or `after:` as a hash (e.g. `"{\"after\":33}"`). See below for a technique to provide `before:` and `after:` using form helpers.**

Position parameters can be strings or symbols, so you can provide them from the browser.

Here are some examples:

##### Creating

```ruby
# Added to the third position, other records are moved out of the way
list.items.create name: 'Item', position: 3

# Added to the end of the list
list.items.create name: 'Item'
list.items.create name: 'Item', position: :last
list.items.create name: 'Item', position: nil
list.items.create name: 'Item', position: {before: nil}

# Added to the start of the list
list.items.create name: 'Item', position: :first
list.items.create name: 'Item', position: {after: nil}

# Added before other_item
list.items.create name: 'Item', position: {before: other_item}
# or
other_item.id # => 22
list.items.create name: 'Item', position: {before: 22}

# Added after other_item
list.items.create name: 'Item', position: {after: other_item}
# or
other_item.id # => 11
list.items.create name: 'Item', position: {after: 11}
```

##### Updating

```ruby
# Moved to the third position, other records are moved out of the way
item.update position: 3

# Moved to the end of the list
item.update position: :last
item.update position: nil
item.update position: {before: nil}

# Moved to the start of the list
item.update position: :first
item.update position: {after: nil}

# Moved to before other_item
item.update position: {before: other_item}
# or
other_item.id # => 22
item.update position: {before: 22}

# Moved to after other_item
item.update position: {after: other_item}
# or
other_item.id # => 11
item.update position: {after: 11}
```

##### Relative Positioning in Forms

It can be tricky to provide the hash forms of relative positioning using Rails form helpers, but it is possible. We've declared a special `Struct` for you to use for this purpose.

Firstly you need to allow both scalar and nested Strong Parameters for the `position` column like so:

```ruby
def item_params
  params.require(:item).permit :name, :position, { position: :before }
end
```

In the example above we're always declaring what item (by its `id`) we want to position our item **before**. You could change this to `:after` if you'd rather.

Next, in your `new` method you may wish to initialise the `position` column with a value supplied by incoming parameters:

```ruby
def new
  item.position = { before: params[:before] }
end
```

You can now just pass the `before` parameter (the `id` of the item you want to add this record before) via the URL to the `new` action. For example: `items/new?before=22`.

In the form itself, so that your intended position survives a failed `create` attempt and form redisplay you can declare the `position` value like so:

```
  <% if item.new_record? %>
    <%= form.fields :position, model: Positioning::RelativePosition.new(item.position_before_type_cast) do |fields| %>
      <%= fields.hidden_field :before %>
    <% end %>
  <% end %>
```

The key part here is `Positioning::RelativePosition.new(item.position_before_type_cast)`. `Positioning::RelativePosition` is a `Struct` that can take `before` and `after` as parameters. You should only provide one or the other. Because `position` is an `Integer` column, the hash structure is obliterated when it is assigned but we can still access it with `position_before_type_cast`. Remember to adjust the method if your position column has a different name (e.g. `category_position_before_type_cast`). The `Struct` provides the correct methods for `fields` to display the nested value.

#### Destroying

When a record is destroyed, the positions of relative items in the scope will be shuffled to close the gap left by the destroyed record. If we detect that records are being destroyed via a scope dependency (e.g. `has_many :items, dependent: :destroy`) then we skip closing the gaps because all records in the scope will eventually be destroyed anyway.

#### Scopes
Positioning handles things for you when you change the scope of a record. If you move a record from one scope to another, the gap in the position column will be healed in the scope the record is leaving, and by default (unless you specify an explicit position) the record will be added to the end of the list in the new scope.

Here are some examples of scope management:

```ruby
# Moved to being the third item in other_list
item.update list: other_list, position: 3

# Moved to the end of other_list
item.update list: other_list
item.update list: other_list, position: :last
item.update list: other_list, position: nil
item.update list: other_list, position: {before: nil}

# Moved to the start of other_list
item.update list: other_list, position: :first
item.update list: other_list, position: {after: nil}

# Moved to before other_item in other_list
item.update list: other_list, position: {before: other_item}
# or
other_item.id # => 22
item.update list: other_list, position: {before: 22}

# Moved to after other_item in other_list
item.update list: other_list, position: {after: other_item}
# or
other_item.id # => 11
item.update list: other_list, position: {after: 11}
```

It's important to note that in the examples above, `other_item` must already belong to the `other_list` scope.

## Concurrency

The queries that this gem runs, especially those that seek the next position integer available are vulnerable to race conditions. To this end, we've introduced an Advisory Lock to ensure that our model callbacks that determine and assign positions run sequentially. In short, an advisory lock prevents more than one process from running a particular block of code at the same time. The lock occurs in the database (or in the case of SQLite, on the filesystem), so as long as all of your processes are using the same database, the lock will prevent multiple positioning callbacks from executing on the same table and positioning column combination at the same time.

If you are using SQLite, you'll want to add the following line to your database.yml file in order to increase the exclusivity of Active Record's default write transactions:

```yaml
default_transaction_mode: EXCLUSIVE
```

You may also want to try `IMMEDIATE` as a less aggressive alternative.

You're encouraged to review the Advisory Lock code to ensure it fits with your environment:

https://github.com/brendon/positioning/blob/main/lib/positioning/advisory_lock.rb

If you have any concerns or improvements please file a GitHub issue.

### Opting out of Advisory Lock

There are cases where Advisory Lock may be unwanted or unnecessary, for instance, if you already lock the parent record in **every** operation that will touch the database on the positioned item, **everywhere** in your application.

Example of such scenario in your application:

```ruby
list = List.create(name: "List")

list.with_lock do
  item_a = list.items.create(name: "Item A")
  item_b = list.items.create(name: "Item B")
  item_c = list.items.create(name: "Item C")

  item_c.update(position: {before: item_a})

  item_a.destroy
end
```

Therefore, making sure you already have another mechanism to avoid race conditions, you can opt out of Advisory Lock by setting `advisory_lock` to `false` when declaring positioning:

```ruby
belongs_to :list
positioned on: :list, advisory_lock: false
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

This gem is tested against SQLite, PostgreSQL and MySQL. The default database for testing is MySQL. You can target other databases by prepending the environment variable `DB=sqlite` or `DB=postgresql` before `rake test`. For example: `DB=sqlite rake test`.

The PostgreSQL and MySQL environments are configured under `test/support/database.yml`. You can edit this file, or preferably adjust your environment to support password-less socket based connections to these two database engines. You'll also need to manually create a database named `positioning_test` in each.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/brendon/positioning.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
