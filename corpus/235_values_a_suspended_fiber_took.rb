# A fiber that stops in the middle of an expression still holds what it took
# out of a collection before it stopped -- popped, shifted, deleted, fetched
# and then removed -- although nothing else names it any more. A collection
# while it is suspended must keep those objects whole: they come back with
# their instance variables, their elements and their class.
class Box
  include Comparable
  attr_reader :v
  def initialize(v) = @v = v
  def <=>(o) = v <=> o.v
  def inspect = "#<Box #{@v}>"
end

# GC.start collects only where nothing is in flight -- at the top level, not
# inside a method -- so the collections are written out at the top level.
shapes = {
  pop:        -> (q, h) { [q.pop, Fiber.yield] },
  shift:      -> (q, h) { [q.shift, Fiber.yield] },
  delete_at:  -> (q, h) { [q.delete_at(1), Fiber.yield] },
  slice!:     -> (q, h) { [q.slice!(0, 2), Fiber.yield] },
  hdelete:    -> (q, h) { [h.delete(:k), Fiber.yield] },
  hshift:     -> (q, h) { [h.shift, Fiber.yield] },
  interp:     -> (q, h) { "#{q.pop.v}-#{Fiber.yield}" },
  args:       -> (q, h) { [q.pop, q.pop].push(Fiber.yield) },
  hash_lit:   -> (q, h) { { a: q.pop, b: Fiber.yield } },
  binop:      -> (q, h) { q.pop.v + Fiber.yield.to_i },
  nested:     -> (q, h) { [[q.pop, [h.delete(:k)]], Fiber.yield] },
  call_arg:   -> (q, h) { Array(q.pop).push(Fiber.yield) },
  range:      -> (q, h) { [(q.pop..q.pop), Fiber.yield] },
}

# A suspended fiber per shape, all of them stopped at once, then the
# collections, then each one resumed.
fibers = shapes.map do |name, body|
  q = [Box.new(1), Box.new(2), Box.new(3)]
  h = { k: [Box.new(10), "str"], z: Box.new(20) }
  f = Fiber.new { body.call(q, h) }
  f.resume
  q.clear
  h.clear
  [name, f]
end
GC.start
junk = (1..3000).map { |i| [i.to_s, { i => Box.new(i) }, "s" * (i % 7)] }
GC.start
junk = nil
GC.start
fibers.each { |name, f| p [name, f.resume(5)] }
