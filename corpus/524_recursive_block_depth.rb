# A recursive block must raise a Ruby exception, just like a recursive method.
# Compare the outcome, not the implementation-dependent recursion depth.
def report_overflow(label)
  before = caller.length
  begin
    yield
  rescue SystemStackError => error
    outcome = [label, error.class, error.message]
  end
  p outcome + [caller.length == before]
end

h = {call: -> { h[:call].call }}
report_overflow(:lambda) { h[:call].call }
h = nil
GC.start

recursive = proc { recursive.call }
report_overflow(:proc) { recursive.call }
recursive = nil
GC.start

# This path enters blocks through a builtin yield rather than Proc#call.
each_again = ->(*) { [1].each(&each_again) }
report_overflow(:each) { each_again.call }
each_again = nil
GC.start

# A suspended fiber's frames must not consume the active fiber's depth budget.
waiting = Fiber.new { Fiber.yield :waiting; :resumed }
p waiting.resume
p Fiber.new {
  again = -> { again.call }
  report_overflow(:fiber) { again.call }
  [1, 2, 3].map { |n| n * 2 }
}.resume
p waiting.resume
GC.start

# Unwinding the guard must restore call depth and normal block control flow.
def finite_block_depth(n, &block)
  n == 0 ? block.call : [n].map { finite_block_depth(n - 1, &block) }.first
end
p finite_block_depth(100) { :recovered }
p [1, 2, 3].map { |n| next n + 10 }
p [1, 2, 3].each { |n| break :done if n == 2 }
