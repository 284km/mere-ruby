# `super(a, b)` and a bare `super` with positional values and no block are
# made from the values on the VM, by the half of ESuper's arm after its
# arguments (super_vals). Everything super can find or refuse, as before.

class Base
  def initialize(a, b = 2) = (@a = a; @b = b)
  def v = [@a, @b]
  def m(x) = [:base, x]
  def z(x, y = 1) = [:base_z, x, y]
end
class Kid < Base
  def initialize(a) = (super(a, a * 10); @k = 1)
  def m(x) = super(x + 1)
  def z(x, y = 5)
    x = x * 2
    super
  end
end
k = Kid.new(3)
p k.v, k.m(1), k.z(4), k.z(4, 9)

# through a module, and the block the frame has passed on
module Loud
  def m(x) = super(x).push(:loud)
  def each_twice = super
end
class Kid2 < Kid
  include Loud
  def each_twice = yield(1)
end
class Kid3 < Kid2
  def each_twice = super
end
p Kid2.new(1).m(1), Kid3.new(1).each_twice { |x| x + 41 }

# Class#new from a `def self.new`, and a definition hook's no-op
class Made
  def self.new(*a) = super(*a)
  def initialize(x) = @x = x
  def x = @x
end
p Made.new(5).x
class Hooked
  def self.inherited(c) = super(c)
end
p Class.new(Hooked).superclass

# nothing above it, and the refusals
class Lone
  def go(x) = super(x)
end
begin
  Lone.new.go(1)
rescue NoMethodError => e
  p e.message
end
class Sub < Base
  def m(x) = super(x)
end
begin
  Object.new.instance_eval { Sub.instance_method(:m).bind_call(self, 1) }
rescue TypeError => e
  p e.class
end
class Dm < Base
  define_method(:m) { |x| super }
end
begin
  Dm.new(1).m(2)
rescue RuntimeError => e
  p e.message[0, 40]
end

# a singleton's super reaches a module it was extended with
mod = Module.new { def hi(n) = [:mod, n] }
o = Object.new
o.extend(mod)
def o.hi(n) = super(n + 1)
p o.hi(1)

# many, with a collection between
objs = Array.new(2000) { |i| Kid.new(i) }
GC.start
p objs.sum { |x| x.v.sum }
