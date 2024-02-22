$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "positioning"
require "support/active_record"

require "minitest/hooks/test"
require "minitest/autorun"
require "mocha/minitest"
