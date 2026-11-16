# Two calls that are answered without a frame: an attribute read, once the
# dispatcher has gone the whole way for that class and name (attr_ic), and a
# method that only stores its arguments (`def initialize(a, b); @a = a; @b =
# b; end`). What has to hold is everything that can change the answer AFTER
# the short way was learnt -- a redefinition, a private or protected mark, a
# prepended module, a singleton method, a refinement, an undef -- and
# everything the full way refuses: a frozen receiver, a wrong count of
# arguments, keywords.
class Point
  attr_reader :x, :y
  attr_accessor :tag
  def initialize(x, y)
    @x = x
    @y = y
  end
  def set(a, b)
    @x = a
    @y = b
  end
  def sum = x + y
  def other_x(o) = o.x
end

pt = Point.new(1, 2)
3.times { print pt.x, pt.y, pt.sum, " " }
puts
p pt.instance_variables, pt.set(5, 6), [pt.x, pt.y], (pt.tag = :t), pt.tag

# the reader redefined, after the read was learnt
class Point
  def x = @x * 10
end
p pt.x, pt.sum
class Point
  attr_reader :x
end
p pt.x, pt.sum

# made private: a call with a receiver is refused, one without is not
class Point
  private :x
end
p((pt.x rescue $!.class), pt.sum, pt.other_x(pt)) rescue p $!.class
class Point
  public :x
  protected :y
end
p pt.x, (pt.y rescue $!.class), pt.sum
class Point
  public :y
end
p pt.y

# one object's own method, a subclass's, a prepended module's
q = Point.new(3, 4)
def q.x = 100
p q.x, pt.x, q.sum
class Sub < Point
  def y = :sub
end
s = Sub.new(7, 8)
p s.x, s.y, Point.new(7, 8).y
module Loud
  def x = "loud #{super}"
end
p pt.x
Point.prepend(Loud)
p pt.x, Point.new(0, 0).x
Point.class_eval { remove_method :y }
p((pt.y rescue $!.class))
class Point
  attr_reader :y
  alias why y
end
p pt.y, pt.why
Point.class_eval { undef_method :why }
p((pt.why rescue $!.class))

# a refinement is seen only where it is in use
class Plain
  attr_reader :v
  def initialize(v) = @v = v
end
pl = Plain.new(1)
p pl.v, pl.v
module Twice
  refine(Plain) { def v = super * 2 }
end
p pl.v
using Twice
p pl.v

# what the store-only method refuses, as the full way does
p((Point.new(1) rescue $!.message), (Point.new(1, 2, 3) rescue $!.message), (pt.set(1) rescue $!.class))
fr = Point.new(1, 2).freeze
p((fr.set(3, 4) rescue [$!.class, $!.message.sub(/0x\h+/, "0x")]), fr.x.class)
p(begin; fr.tag = 1; rescue => e; e.class; end)

class Keys
  attr_reader :a, :b
  def initialize(a, b)
    @a = a
    @b = b
  end
end
k = Keys.new(1, x: 2)
p k.a, k.b, k.b.class
h = { y: 3 }
k = Keys.new(h, h)
p k.a.equal?(h), k.b.equal?(h)
p Keys.new(*[1, 2]).b, (Keys.new(*[1]) rescue $!.class)

# a block given, and a TracePoint, still see the method
class Blk
  attr_reader :n
  def initialize(n)
    @n = n
  end
end
events = []
tp = TracePoint.new(:call, :c_call) { |t| events << [t.event, t.method_id] if t.method_id == :initialize || t.method_id == :n }
tp.enable { b = Blk.new(1); b.n }
p events
p Blk.new(2) { :unused }.n

# the value a store-only method answers, and a class variable beside it
class Mix
  def both(a, b)
    @p = a
    @q = b
  end
  def cls(a)
    @@c = a
  end
  def under(_, _)
    @u = _
  end
end
m = Mix.new
p m.both(1, [2]), m.cls(9), Mix.class_variable_get(:@@c), m.under(1, 2), m.instance_variables

# an implicit `x` and an explicit `x!`
class Bang86
  attr_reader :x
  def initialize = @x = :reader
  def read = x
  def x! = :bang
end
o = Bang86.new
p o.read, o.x!, o.read, o.x!
class Bang86b
  attr_reader :y
  alias_method :x!, :y
  def initialize = (@y = :y; @x = :xval)
  def x = @x
  def read = x
end
o2 = Bang86b.new
p o2.x!, o2.read, o2.x!, o2.read

# a reader that fills its variable the first time (`@n ||= 0`, as
# test/unit's _assertions), and the same two kinds of method in a file that
# says `binding` -- this one -- where the parser puts a mark in front of
# every body
class Count
  def n = @n ||= 0
  def n=(v)
    @n = v
  end
  def flag = @flag ||= :set
  def none = @none ||= nil
  def off = @off ||= false
  def name = @name ||= "s"
end
c = Count.new
p c.n, (c.n += 1), (c.n += 1), c.n, c.instance_variables
c.n = nil
p c.n, c.n.class
c.n = false
p c.n
p c.flag, c.none, c.none, c.off, c.instance_variables, c.name, c.name.frozen?, c.name.equal?(c.name)
fc = Count.new
p((fc.freeze.n rescue $!.class))
fc2 = Count.new
fc2.n = 5
fc2.freeze
p fc2.n, begin; fc2.n = 6; rescue => e; e.class; end
p binding.local_variable_defined?(:c), Count.instance_method(:n).arity
