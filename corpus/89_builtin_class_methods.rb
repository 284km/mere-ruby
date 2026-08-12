# A built-in class method has no entry in the user method table, so
# `respond_to?` and `method` have to know it. timeout.rb opens with
# `GET_TIME = Process.method(:clock_gettime)`, which raised here -- while the
# same call written out worked, because that path never asks.
p Process.respond_to?(:clock_gettime)
p Process.method(:clock_gettime).class
p Process.method(:clock_gettime).call(Process::CLOCK_MONOTONIC).class
p Process.respond_to?(:no_such_thing_at_all)

p GC.respond_to?(:start)
p GC.method(:start).call
p Math.respond_to?(:sqrt)
p Math.method(:sqrt).call(9)
p Math.method(:hypot).call(3, 4)
p Math.respond_to?(:no_such_function)

# ...and the ordinary answers are unchanged
p String.respond_to?(:new)
p String.respond_to?(:name)
class Own
  def self.mine = :mine
end
p Own.respond_to?(:mine)
p Own.method(:mine).call
p Own.respond_to?(:not_mine)
