# A method whose body only stores its parameters in instance variables --
# the evaluator's triv_store_body -- runs without a frame on the VM as well.
# What such a call answers, and every case that is not that shape, as before.

class One
  def initialize(a) = @a = a
  attr_reader :a
end
class Three
  def initialize(a, b, c)
    @a = a
    @b = b
    @c = c
  end
  def set(x, y)
    @a = x
    @b = y
  end
  def vals = [@a, @b, @c]
end
p One.new(1).a, Three.new(1, :b, "c").vals
t = Three.new(1, 2, 3)
p t.set(:x, :y), t.vals

begin
  Three.new(1, 2)
rescue ArgumentError => e
  p e.message
end
begin
  t.set(1)
rescue ArgumentError => e
  p e.message
end

# not that shape: `_`, a class variable, a literal, a parameter used twice
class Odd
  @@seen = nil
  def initialize(_, b) = @b = b
  def cv(v) = @@seen = v
  def lit = @k = 5
  def twice(v)
    @p = v
    @q = v
  end
  def self.seen = @@seen
  def all = [@b, @k, @p, @q]
end
o = Odd.new(1, 2)
p o.cv(:c), Odd.seen, o.lit, o.twice(9), o.all

# a frozen receiver refuses the store
f = Three.new(1, 2, 3).freeze
begin
  f.set(4, 5)
rescue FrozenError => e
  p e.class
end

# many objects, and a collection between
objs = Array.new(3000) { |i| Three.new(i, i * 2, i * 3) }
GC.start
p objs.sum { |x| x.vals.sum }

# keywords, a splat, a default: the full path
class Kw
  def initialize(a:, b: 2) = (@a = a; @b = b)
  def v = [@a, @b]
end
p Kw.new(a: 1).v
class Sp
  def initialize(*r) = @r = r
  def r = @r
end
p Sp.new(1, 2).r
