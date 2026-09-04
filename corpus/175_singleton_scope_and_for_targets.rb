# Two things a singleton-class body has to get right at once, and the `for`
# target list's splat.
#
# `class << obj` ran with the SINGLETON's own name as its lexical scope, so a
# bare constant in the body was looked up under "(sng:111)" and then along that
# singleton's ancestors -- which stop at Object. `class << self` hid it for a
# long time: THAT singleton's ancestors do include the enclosing module, so its
# constants were found by the second route and only a singleton of some other
# object showed the missing cref.
#
# Naming the enclosing module alone was not right either: a class defined in
# the body belongs to that singleton, so `class << a` and `class << b` each
# get their own X. Sharing one class let the second body's CONST overwrite the
# first's. The scope keeps the singleton as its innermost segment, so
# definitions land under it and a lookup still walks out to the module.

module N
  B = 2
  o = Object.new
  class << o
    p B
  end
  O2 = Object.new
  class << O2
    p B
  end
  def self.mk
    x = Object.new
    class << x
      p B
      def v; B; end
    end
    x
  end
  p mk.v
  class << self
    p B
  end
end

module M2
  A = 1
  class Inner; p A; end
  obj = Object.new
  class << obj
    p A
    class X
      p A
    end
  end
end

class K2
  C = 3
  o = Object.new
  class << o
    p C
  end
end

B0 = 9
q = Object.new
class << q
  p B0
end

# each singleton's nested class is ITS OWN, with its own constants
module CS
  PAIR = [Object.new, Object.new]
  CLASSES = []
  2.times do |i|
    obj = PAIR[i]
    $which = i
    class << obj
      class X
        CLASSES << self
        CONST = ($which + 1)
        def foo; CONST; end
      end
    end
  end
end
p CS::CLASSES.size
p CS::CLASSES[0] != CS::CLASSES[1]
p CS::CLASSES[0].new.foo
p CS::CLASSES[1].new.foo

# `for` target lists. The paren arm and the splat arm both matched the same
# token kind and the first one won, so the splat arm was dead code and every
# `for *r in` / `for a, *r in` failed to parse. A lone `*r` also has to
# COLLECT: `for *r in [[1,2]]` is the assignment `*r = [1,2]`.
for i, in [[1, 2]]; p i; end
for i, * in [[1, 2]]; p i; end
for *r in [[1, 2]]; p r; end
for *r in [1, 2]; p r; end
for * in [[1, 2]]; p :ran; end
for a, b, *r in [[1, 2, 3, 4]]; p [a, b, r]; end
for a, *r in [[1, 2, 3]]; p [a, r]; end
for (a, b) in [[1, 2]]; p [a, b]; end
for x in [1, 2]; p x; end
for k, v in { a: 1 }; p [k, v]; end

# a nested masgn whose targets are accessor calls on a singleton
object = Object.new
class << object
  attr_accessor :a, :b
end
(object.a, object.b), c = [:a, :b], nil
p [object.a, object.b, c]

# A multiple assignment whose TARGETS are parenthesized receivers, which is how
# ruby/spec pins evaluation order. The same `(` opens a destructuring group and
# a parenthesized receiver; which one it is shows up after the matching close
# paren -- a group is followed by `,` or `=`, a receiver by a call. Reading
# every `(` as a group made the whole spec file a parse error.
#
# A `;` lexes as a newline, and a newline inside the parens does not end the
# statement -- stopping there said this was not a multiple assignment at all.
# A grouped target list may also WRAP after its comma, the same way the outer
# list may.
st = Struct.new(:x, :y)
o = st.new
r = []
(r << :a; o).x, (r << :b; o).y = (r << :c; :c), (r << :d; :d)
p [r, o.x, o.y]

o2 = st.new
r2 = []
(r2 << :a; o2).x, y2 = 1, 2
p [r2, o2.x, y2]

o3 = st.new
r3 = []
z3, (r3 << :a; o3).x = 1, 2
p [r3, o3.x, z3]

a, (b,
  c) = 1, [2, 3]
p [a, b, c]

deep = Struct.new(:a, :b, :c, :d, :e, :f).new
r4 = []
(r4 << :a; deep).a,
  ((r4 << :b; deep).b,
  ((r4 << :c; deep).c, (r4 << :d; deep).d),
  (r4 << :e; deep).e),
(r4 << :f; deep).f = (r4 << :value; :value)
p r4

idx = Object.new
def idx.[]=(k, v) (@h ||= {})[k] = v; end
def idx.[](k) (@h ||= {})[k]; end
r5 = []
(r5 << :a; idx)[(r5 << :b; :b)], (r5 << :c; idx)[(r5 << :d; :d)] = (r5 << :e; :e), (r5 << :f; :f)
p [r5, idx[:b], idx[:d]]

w, (e, f) = 1, [2, 3]
p [w, e, f]
((g, h), i) = [[4, 5], 6]
p [g, h, i]

# `self[k], self[j] = ...` and `self::A, self::B = ...`: the same assignment
# through []= and a constant write. Only `self.attr` was recognised, so a
# method that writes two subscripts of self was not read as an assignment at
# all -- and a constant write was the one target kind whose receiver was NOT
# pre-evaluated, so it ran after the RHS and the recorded order came out
# reversed.
holder = Object.new
class << holder
  def []=(key, v); (@h ||= {})[key] = v; end
  def [](key); (@h || {})[key]; end
  def assign(k1, v1, k2, v2)
    self[k1], self[k2] = v1, v2
  end
end
holder.assign :k1, :v1, :k2, :v2
p [holder[:k1], holder[:k2]]

mod = Module.new
mod.module_exec { self::A, self::B = :v1, :v2 }
p [mod::A, mod::B]

mod2 = Module.new
mod2.module_exec { (self::A, self::B), c = [:v1, :v2], nil }
p [mod2::A, mod2::B]

mod3 = Module.new
order = []
(order << :a; mod3)::A, (order << :b; mod3)::B = (order << :c; :c), (order << :d; :d)
p [order, mod3::A, mod3::B]

mod4 = Module.new
order4 = []
((order4 << :a; mod4)::A, unused), rest = [(order4 << :b; :b)]
p [order4, mod4::A]

class Named; end
Named::X, Named::Y = 1, 2
p [Named::X, Named::Y]

class Both
  attr_accessor :p, :q
  def set; self.p, self.q = 1, 2; end
end
b2 = Both.new
b2.set
p [b2.p, b2.q]
