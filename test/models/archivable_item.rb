class ArchivableItem < ActiveRecord::Base
  belongs_to :list

  positioned on: [:list, :archived_at]

  default_scope { where(archived_at: nil) }
end
