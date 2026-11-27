# A `return` out of a block carries its value through the frames between, and
# where it lands the value is the caller's. Left behind in the flow's own slot
# it was a root for good: after a second such return, both values were alive
# where ruby keeps no more than the last one.
class Mark1074; end
def with_block = yield(Array.new(1000) { Mark1074.new })
def r1 = (with_block { |a| return a }; nil)
def r2 = with_block { |a| a.size }
class Holder1074
  def initialize(&b) = @b = b
  def go = @b.call(Array.new(1000) { Mark1074.new })
end
def r3 = (Holder1074.new { |a| return a }.go; nil)
last = nil
%i[r2 r1 r2 r3 r2].each do |m|
  send(m)
  GC.start
  x = [1].map(&:to_s)
  GC.start
  last = ObjectSpace.each_object(Mark1074).count
end
# (no more than one returned value's 1,000 objects is kept)
p last < 1500

# the values themselves arrive whole
def ret_value = with_block { |a| return a }
p ret_value.size, ret_value.first.class
def find_first(xs) = xs.each { |x| return x if x > 2 }
p find_first([1, 2, 3, 4]), find_first([1])
def brk = with_block { |a| break a.size + 1 }
p brk
def tagged = catch(:t) { [1, 2].each { |i| throw :t, [i, :thrown] } }
p tagged
pr = proc { |v| next v * 2 }
p pr.call(21)
