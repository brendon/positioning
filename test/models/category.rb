class Category < ActiveRecord::Base
  belongs_to :parent, class_name: "Category", optional: true

  positioned on: :parent
end
