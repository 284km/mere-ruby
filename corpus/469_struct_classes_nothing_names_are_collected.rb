# Struct classes are collected when nothing names them; the ones something
# does name keep every method across collections
code = proc { Struct.new("A", :x); Struct.send(:remove_const, :A) }
3000.times(&code)
GC.start

S = Struct.new(:a, :b) { def sum = a + b }
s = S.new(1, 2)
anon = Struct.new(:x).new(5)          # an instance keeps its class
um = Struct.new(:q).instance_method(:q) # an UnboundMethod keeps its owner
bm = Struct.new(:w).new(9).method(:w)   # a Method too
sub = Class.new(Struct.new(:z))         # a subclass keeps its parent
held = [Struct.new(:h)]                 # a value in an Array
kw = Struct.new(:k, keyword_init: true)
3000.times(&code)
GC.start
3000.times(&code)
GC.start

p s, s.sum, S.members
p anon.x, anon.class.members, anon.to_a
p um.owner.members, um.name
p bm.call, bm.owner.members
p sub.new(3).z, sub.superclass.members
p held[0].new(7).h, held[0].members
p kw.new(k: 1).k
p Struct.new("B", :y).new(4).y, Struct::B.members
p S.new(3, 4) == S.new(3, 4), S.new(1, 2).eql?(s)
