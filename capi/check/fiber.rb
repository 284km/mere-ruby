require '-test-/iter'
$count = 0
def check(value)
  raise 'fiber contract failed' unless value
  $count += 1
end
# A call into C stays with the stack it is on. `each_from_c` is in C
# (rb_block_call) when its block gives up the fiber; another fiber's own call
# into C runs meanwhile, and the first continues where it stopped.
class Seq
  include Bug::Iter::Yield
  def initialize(*values) = @values = values
  def each
    @values.each { |v| yield v }
    :done
  end
  def each_from_c(&block) = yield_block(:each, &block)
end
log = []
a = Fiber.new do
  result = Seq.new(1, 2, 3).each_from_c { |v| log << [:a, v]; Fiber.yield v }
  log << [:a, result]
  :a_ended
end
b = Fiber.new do
  result = Seq.new(10, 20).each_from_c { |v| log << [:b, v]; Fiber.yield v }
  log << [:b, result]
  :b_ended
end
check(a.resume == 1)
check(b.resume == 10)
check(Seq.new(7).each_from_c { |v| log << [:main, v] } == :done)
check(a.resume == 2)
GC.start
check(b.resume == 20)
check(a.resume == 3)
check(b.resume == :b_ended)
check(a.resume == :a_ended)
check(log == [[:a, 1], [:b, 10], [:main, 7], [:a, 2], [:b, 20], [:a, 3], [:b, :done], [:a, :done]])
# an exception raised in a fiber that is inside C unwinds that fiber's C call,
# not the one another stack is in the middle of
c = Fiber.new do
  Seq.new(1, 2).each_from_c { |v| Fiber.yield v }
end
d = Fiber.new do
  begin
    Seq.new(5).each_from_c { |v| Fiber.yield v; raise ArgumentError, 'from d' }
  rescue ArgumentError => e
    e.message
  end
end
check(c.resume == 1)
check(d.resume == 5)
check(d.resume == 'from d')
check(c.resume == 2)
check(c.resume == :done)
# a thread switch in the middle of a C call
order = []
threads = 3.times.map do |i|
  Thread.new do
    Seq.new(i, i + 10).each_from_c { |v| order << v; Thread.pass }
  end
end
check(threads.map(&:value) == [:done, :done, :done])
check(order.sort == [0, 1, 2, 10, 11, 12])
puts "native fiber contracts: #{$count} passed"
