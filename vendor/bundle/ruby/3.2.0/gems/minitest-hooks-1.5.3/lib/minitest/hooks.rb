require 'minitest/hooks/test'
require 'minitest/spec'

# Spec subclass that includes the hook methods.
class Minitest::HooksSpec < Minitest::Spec
  include Minitest::Hooks
end
