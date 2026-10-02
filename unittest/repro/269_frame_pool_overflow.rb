# Run under test/unit's runner with tool/lib on -I, from <ruby-src>/test/ruby:
#   RUBYLIB=<stdlib> mere-ruby -I ../../tool/lib <this file>
# Stopped silently (CPU 0%) up to c0e7377 -- a recycled frame bump-allocated past
# a dedicated block into the heap (note 269); with tools/asan_build.sh it was a
# use-after-poison in bind_params under Test::Unit::TestCase#run. Now: 1 Failure.
require 'test/unit'
class TUaf < Test::Unit::TestCase
  CHILD = 'p :ok; 10.times { ObjectSpace.define_finalizer(Object.new, proc { raise ArgumentError, "wrong number of arguments (given 3, expected 0)" }) }'
  def test_a
    assert_in_out_err(["-e", CHILD], "", %w(:ok), [])
  end
end
