class DefaultScopeItem < ActiveRecord::Base
  belongs_to :list

  positioned on: :list

  default_scope -> { select(:name, :position).order(:position) }
end
