class SoftDeletableItem < ActiveRecord::Base
  belongs_to :list

  positioned on: :list

  default_scope { where(deleted_at: nil) }

  def destroy
    run_callbacks(:destroy) { update_columns(deleted_at: Time.current) }
  end
end
