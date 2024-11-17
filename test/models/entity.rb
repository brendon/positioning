class Entity < ActiveRecord::Base
  belongs_to :includable, polymorphic: true

  positioned on: :includable
end
