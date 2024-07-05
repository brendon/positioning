class ItemWithoutAdvisoryLock < ActiveRecord::Base
  belongs_to :list

  positioned on: :list, advisory_lock: false
end
