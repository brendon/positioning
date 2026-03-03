# A model that simulates soft-delete behavior like acts_as_paranoid or discard.
# Soft-deleted records have a non-nil deleted_at timestamp and are excluded
# from the default scope.
class ParanoidItem < ActiveRecord::Base
  belongs_to :list

  # Simulate a soft-delete gem's default scope that excludes deleted records
  default_scope { where(deleted_at: nil) }

  # Use record_scope: :unscoped so positioning can find soft-deleted records
  # when recovering them or when updating positions
  positioned on: :list, record_scope: :unscoped

  # Simulate soft-delete behavior
  def soft_delete
    update_column :deleted_at, Time.current
  end

  # Simulate recovery from soft-delete
  def recover
    # This would fail without record_scope: :unscoped because the default_scope
    # excludes deleted records, so record_scope.pick(:position) would return nil
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
