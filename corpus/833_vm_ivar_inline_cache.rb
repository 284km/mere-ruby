# An instance variable read or written by the same instruction for objects
# of different shapes, classes and histories, as the ISeq VM's inline cache
# keeps them (note 559, step 2c): the shape it was last read in, or the
# shape before and after a write; a removed variable read and set again, its
# place in the order last; a frozen object; a class variable; an object with
# many variables and one whose area grows; dup and clone; a BasicObject.
class P
  def initialize(a, b) = (@a = a; @b = b)
  def sum = @a + @b
  def set_c(v) = (@c = v)
  def c = @c
  attr_accessor :a, :b
end
class Q
  def initialize = (@b = 10; @a = 20)
  def sum = @a + @b
end
ps = (1..5).map { |i| P.new(i, i * 10) }
p ps.map(&:sum), ps.map(&:c)
def rd(o) = o.instance_variable_get(:@a)
p [P.new(1, 2).sum, Q.new.sum]
objs = [P.new(1, 2), Q.new, P.new(3, 4), Q.new]
p objs.map(&:sum)
x = P.new(1, 2); x.set_c(3); p [x.c, x.instance_variables]
x.remove_instance_variable(:@a); p [x.instance_variables, (x.a rescue $!.class), x.a.inspect]
x.a = 9; p [x.instance_variables, x.a, x.sum]
y = P.new(5, 6).freeze
p((y.set_c(1) rescue [$!.class, $!.message[0, 30]]))
z = P.new(7, 8); z2 = z.dup; z2.a = 70; p [z.a, z2.a, z.clone.instance_variables]
class R; @@n = 0; def bump = (@@n += 1); def n = @@n; end
r = R.new; 3.times { r.bump }; p r.n
o = Object.new; o.instance_eval { @q = 1; @r = 2 }; p o.instance_variables, o.instance_eval { @q + @r }
class Many
  def initialize(n) = n.times { |i| instance_variable_set("@v#{i}", i) }
  def first = @v0
  def set0(v) = (@v0 = v)
end
ms = [Many.new(3), Many.new(20), Many.new(1)]
ms.each { |m| m.set0(m.first.to_i + 100) }; p ms.map(&:first)
class Grow
  def go = (@a = 1; @b = 2; @c = 3; @d = 4; @e = 5; @f = 6; @g = 7; @h = 8; @i = 9; self)
  def sum = @a + @b + @c + @d + @e + @f + @g + @h + @i
end
p Array.new(4) { Grow.new.go.sum }
class Inh < P; def initialize = super(1, 2) ; def more = (@z = 5; @a + @z); end
p Inh.new.more, Inh.new.instance_variables
b = BasicObject.new; def b.set = (@x = 1; @x); p b.set
p((1.instance_eval { @a = 1 } rescue $!.class))

# one read and one write instruction (a module's method) for objects of three
# classes whose shapes differ, taken in turn: the cache is the last shape's
module AB
  def get_a = @a
  def set_a(v) = (@a = v)
end
class K1; include AB; def initialize = (@a = 1); end
class K2; include AB; def initialize = (@b = 2; @a = 3); end
class K3; include AB; def initialize = (@c = 4; @d = 5); end
ks = [K1.new, K2.new, K3.new, K1.new, K2.new, K3.new]
p ks.map(&:get_a)
ks.each_with_index { |k, i| k.set_a(i) }
p ks.map(&:get_a), ks.map(&:instance_variables)
# two classes that set the same names in the same order share a shape
class S1; def initialize = (@x = 1; @y = 2); def y = @y; end
class S2; def initialize = (@x = 3; @y = 4); def y = @y; end
p [S1.new.y, S2.new.y, S1.new.y]

# the ISeq a cached instruction belongs to reads as ruby's after it has run
class Dis
  def initialize = (@a = 1)
  def get = @a
  def put(v) = (@a = v)
end
d = Dis.new
3.times { d.put(d.get + 1) }
p d.get
p RubyVM::InstructionSequence.of(Dis.instance_method(:get)).to_a.last.select { Array === _1 && _1[0].to_s.include?("instancevariable") }
p RubyVM::InstructionSequence.of(Dis.instance_method(:put)).to_a.last.select { Array === _1 && _1[0].to_s.include?("instancevariable") }
puts RubyVM::InstructionSequence.of(Dis.instance_method(:get)).disasm.lines.grep(/instancevariable/)
