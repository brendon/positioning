class Blog < ActiveRecord::Base
  positioned on: :enabled

  default_scope { order(:position) }
end
