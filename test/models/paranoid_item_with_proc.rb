# A model that simulates soft-delete behavior and uses a proc for record_scope.
# This demonstrates the more targeted approach where only specific scopes are
# removed, rather than using the blanket :unscoped option.
class ParanoidItemWithProc < ActiveRecord::Base
  belongs_to :list

  # Simulate a soft-delete gem's default scope that excludes deleted records
  default_scope { where(deleted_at: nil) }

  # Use a proc to only unscope the deleted_at condition, preserving other
  # default scopes (like multi-tenancy scopes) that might be present
  positioned on: :list, record_scope: ->(scope) { scope.unscope(where: :deleted_at) }

  # Simulate soft-delete behavior
  def soft_delete
    update_column :deleted_at, Time.current
  end

  # Simulate recovery from soft-delete
  def recover
    self.deleted_at = nil
    self.position = :last
    save!
  end

  # Class method to find deleted records (bypassing default scope)
  def self.deleted
    unscoped.where.not(deleted_at: nil)
  end

  # Class method to include deleted records
  def self.with_deleted
    unscoped
  end
end
