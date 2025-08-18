class Channel < ActiveRecord::Base
  belongs_to :blog

  positioned on: [:blog, :active]

  default_scope { where(active: true).order(:position) }
end

