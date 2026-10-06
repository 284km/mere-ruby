# frozen_string_literal: true
# A Ruby stand-in for CRuby's ext/-test-/iter (see -test-/file.rb for why).
module Bug
  module Iter
    # yield.c: call the named method and hand what it yields to the block
    # given here, keywords passed as called (rb_block_call_kw, rb_yield_block)
    module Yield
      def yield_block(name, *args, **kw, &blk)
        __send__(name, *args, **kw) { |*a, **k| k.empty? ? blk.yield(*a) : blk.yield(*a, **k) }
      end
    end
    # break.c: break out of the iteration that is running
    module Breakable
      def self.iter_break = throw(:__bug_iter_break, nil)
      def self.iter_break_value(v) = throw(:__bug_iter_break, v)
    end
  end
end
