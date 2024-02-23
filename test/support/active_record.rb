require "active_record"

ENV["DB"] = "mysql" unless ENV["DB"]

database_configuration = ENV["CI"] ? "test/support/ci_database.yml" : "test/support/database.yml"

ActiveRecord::Base.configurations = YAML.safe_load(IO.read(database_configuration))
ActiveRecord::Base.establish_connection(ENV["DB"].to_sym)

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

  add_index :categorised_items, [:list_id, :position], unique: true
  add_index :categorised_items, [:list_id, :category_id, :category_position], unique: true

  create_table :authors, force: true do |t|
    t.string :name
    t.boolean :enabled, default: true
    t.integer :position, null: false
    t.references :list, null: false
  end

  add_index :authors, [:list_id, :enabled, :position], unique: true
end

# Uncomment the following line to enable SQL logging
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
