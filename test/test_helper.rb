$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "positioning"
require "support/active_record"

require "minitest/hooks/test"
require "minitest/autorun"
require "mocha/minitest"

RAILS_VERSION_WITTH_COMPOSITE_PRIMARY_KEYS = Gem::Version.new("7.1.0")
