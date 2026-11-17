# A copy carries the instance variables of what it copies, and
# `instance_variables` lists them in the order they were first set -- found
# by the object's own list of names, or for a String, an Array or a Hash only
# once one of them has ever been given a variable, and no longer by walking
# every object's variables. What has to hold is what the walk gave: the
# order, a variable removed and set again, a Struct's members beside its
# variables, a singleton class kept by clone and dropped by dup, a String's
# variables on its copy and on `-str`.
class Pt
  attr_accessor :a, :b, :c
  def initialize
    @a = 1
    @b = 2
  end
end

o = Pt.new
o.c = 3
p o.instance_variables, o.dup.instance_variables, o.clone.instance_variables
o.remove_instance_variable(:@a)
o.a = 10
o.instance_variable_set(:@z, 0)
d = o.dup
p o.instance_variables, d.instance_variables, [d.a, d.b, d.c, d.instance_variable_get(:@z)]
d.b = 20
p o.b, d.b, d.equal?(o), d.frozen?, o.freeze.dup.frozen?, o.clone.frozen?

# a singleton class goes with clone, not with dup
s = Pt.new
def s.only = :mine
p s.clone.only, (s.dup.only rescue $!.class), s.clone.instance_variables

# a Struct: its members, and what was set beside them
St = Struct.new(:x, :y) do
  def note=(v)
    @note = v
  end
  attr_reader :note
end
t = St.new(1, [2])
t.note = :n
u = t.dup
p u, u.to_a, u.note, u.instance_variables, t.instance_variables, u.y.equal?(t.y)
u.x = 9
p t.x, u.x, St.new(5).dup.to_a, St.new.dup.instance_variables
K = Struct.new(:k, keyword_init: true)
p K.new(k: 1).dup.k, K.new(k: 1).clone.instance_variables

# an exception, a Time, a Range held in an object
e = RuntimeError.new("m")
e.instance_variable_set(:@why, :w)
f = e.dup
p f.message, f.instance_variable_get(:@why), f.instance_variables, f.class
class R2 < Range; end
r = R2.new(1, 3)
r.instance_variable_set(:@tag, :t) rescue p $!.class
p r.dup.to_a, r.dup.class

# a String, an Array, a Hash: nothing to carry, then something
str = +"abc"
arr = [1, 2]
h = { a: 1 }
p str.dup, arr.dup, h.dup, str.instance_variables, arr.instance_variables, h.instance_variables
p((-str).equal?(-"abc".dup), (-str).frozen?)
str.instance_variable_set(:@s, 1)
arr.instance_variable_set(:@r, 2)
h.instance_variable_set(:@h, 3)
p str.instance_variables, arr.instance_variables, h.instance_variables
p str.dup.instance_variable_get(:@s), arr.dup.instance_variable_get(:@r), h.dup.instance_variable_get(:@h)
p str.clone.instance_variables, arr.clone.instance_variables, h.clone.instance_variables
p "plain".dup.instance_variables, [0].dup.instance_variables, {}.dup.instance_variables
fz = "kept".dup
fz.instance_variable_set(:@mark, true)
fz.freeze
p((-fz).equal?(fz), (-fz).instance_variables, (-"kept".dup).instance_variables)

# many objects alive and dead while it happens
junk = Array.new(3000) { Pt.new }
5000.times { Pt.new }
q = Pt.new
q.c = :last
p q.dup.c, q.dup.instance_variables, junk.last.dup.instance_variables, junk.size
