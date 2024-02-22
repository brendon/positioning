# Positioning

The aim of this gem is to allow you to easily position model instances within a scope of your choosing. In an ideal world this gem will give your model instances sequential integer positions beginning with `1`. Attempts are made to make all changes within a transaction so that position integers remain consistent. To this end, directly assigning a position is discouraged, instead you can move items by declaring an item's prior or subsequent item in the list and your item will be moved to be relative to that item.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/brendon/positioning.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
