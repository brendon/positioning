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

    create_table :entities, force: true do |t|
      t.string :name
      t.integer :position, null: false
      t.references :includable, polymorphic: true
    end

    add_index :entities, [:includable_id, :includable_type, :position], unique: true, name: 'index_entities_on_includable_and_position'

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

    create_table :composite_primary_key_items, primary_key: [:item_id, :account_id], force: true do |t|
      t.integer :item_id, null: false
      t.integer :account_id, null: false
      t.string :name
      t.integer :position, null: false
      t.references :list, null: false
    end

    add_index :composite_primary_key_items, [:list_id, :position], unique: true

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
      t.integer :position, null: false
      t.references :blog
    end

    add_index :posts, [:blog_id, :position], unique: true
    add_index :posts, :order, unique: true
  end
end

# Uncomment the following line to enable SQL logging
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
