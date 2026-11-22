# A builtin's arity is the class's own until the program defines the name:
# the bounds a call is checked against follow a definition, a private mark
# or an include in an anonymous class, its anonymous superclass, or a named
# one (builtin_arity_msg_b's arity_memo, keyed by the class's own lookup
# generation).
c = Class.new(Array)
o = c.new([1, 2])
o.length
c.class_eval { def length(a) = [:mine, a] }
p((o.length(5) rescue $!))
s = Class.new(String)
t = s.new("ab")
t.upcase
s.class_eval { def upcase(x) = [:own, x] }
p((t.upcase(1) rescue $!))
m = Module.new { def size(a) = [:mod, a] }
h = Class.new(Hash)
hh = h.new
hh.size
h.include(m)
p((hh.size(3) rescue $!))
class NamedArr < Array; end
n = NamedArr.new([1])
n.length
NamedArr.class_eval { def length(a) = [:named, a] }
p((n.length(7) rescue $!))
c1 = Class.new(Array)
c2 = Class.new(c1)
o2 = c2.new([1])
o2.length
c1.class_eval { def length(a) = [:parent, a] }
p((o2.length(2) rescue $!))
k = Class.new(Array)
ko = k.new([1])
ko.length
k.class_eval { def length(a) = [:x, a] }
k.class_eval { private :length }
p((ko.length(1) rescue $!.class))
