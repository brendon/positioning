class ItemWithoutAdvisoryLock < ActiveRecord::Base
  belongs_to :list

  positioned on: :list, use_advisory_lock: false
end
