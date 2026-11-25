# A subclass of Fiber has Fiber's instance methods, also when one of its own
# methods calls them with no receiver:
#
#   class ThreadlikeFiber < Fiber
#     def join(timeout = nil)
#       resume while alive? && ...
#
# is activerecord's connection_pool_test. The bare `alive?` was a NameError
# and `respond_to?(:alive?)` false: the table of Fiber's methods was asked by
# the object's own class name.
class TF < Fiber
  def join
    n = 0
    (resume; n += 1) while alive?
    n
  end
  def still = alive?
  def step = resume
  def asks = [respond_to?(:alive?), respond_to?(:resume), respond_to?(:nope)]
end
f = TF.new { Fiber.yield 1; Fiber.yield 2; 3 }
p f.respond_to?(:alive?), f.respond_to?(:resume), f.respond_to?(:transfer)
p f.asks
p f.still, f.step, f.alive?
p f.join, f.alive?, f.still
p TF.instance_method(:alive?).owner, f.class, f.is_a?(Fiber)
# one more level, and a method of its own with a Fiber name wins
class TF2 < TF
  def alive? = :mine
  def probe = alive?
end
g = TF2.new { 1 }
p g.probe, g.respond_to?(:alive?), g.step
# a plain Fiber is as it was
h = Fiber.new { Fiber.yield 1; 2 }
p h.respond_to?(:alive?), h.resume, h.alive?, h.resume, h.alive?
