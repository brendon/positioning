require "active_record"

ENV["DB"] = "mysql" unless ENV["DB"]

database_configuration = ENV["CI"] ? "test/support/ci_database.yml" : "test/support/database.yml"

ActiveRecord::Base.configurations = YAML.safe_load(IO.read(database_configuration))
ActiveRecord::Base.establish_connection(ENV["DB"].to_sym)

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Schema.define version: 0 do
    create_table :lists, force: true do |t|
      t.string :name
    end

    create_table :items, force: true do |t|
      t.string :name
      t.integer :position, null: false
      t.references :list, null: false
    end

    add_index :items, [:list_id, :position], unique: true

    create_table :new_items, force: true do |t|
      t.string :name
      t.integer :position
      t.integer :other_position
      t.references :list, null: false
    end

    create_table :item_with_composite_primary_keys, primary_key: [:item_id, :account_id], force: true do |t|
      t.integer :item_id, null: false
      t.integer :account_id, null: false
      t.string :name
      t.integer :position, null: false
      t.references :list, null: false
    end

    add_index :item_with_composite_primary_keys, [:list_id, :position], unique: true

    create_table :categories, force: true do |t|
      t.string :name
      t.integer :position, null: false
    end

    add_index :categories, :position, unique: true

    create_table :categorised_items, force: true do |t|
      t.string :name
      t.integer :position, null: false
      t.integer :category_position, null: false
      t.references :list, null: false
      t.references :category, null: false
    end

    add_index :categorised_items, [:list_id, :position], unique: true, name: "index_on_list_id_and_position"
    add_index :categorised_items, [:list_id, :category_id, :category_position], unique: true, name: "index_on_list_id_category_id_and_category_position"

    create_table :authors, force: true do |t|
      t.string :name
      t.string :type
      t.boolean :enabled, default: true
      t.integer :position, null: false
      t.references :list, null: false
    end

    add_index :authors, [:list_id, :enabled, :position], unique: true

    create_table :blogs, force: true do |t|
      t.string :name
      t.boolean :enabled, default: true
      t.integer :position, null: false
    end

    add_index :blogs, [:position, :enabled], unique: true

    create_table :posts, force: true do |t|
      t.string :name
      t.integer :order, null: false
    end

    add_index :posts, :order, unique: true
  end
end

# Uncomment the following line to enable SQL logging
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
