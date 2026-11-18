# Module#clone / #dup copy the constants and autoloads the original holds,
# and a module that never had one copies none.

m = Module.new
m.const_set(:A, 1)
m.autoload(:B, "no_such_feature_for_this_witness")
c = m.clone
p c.constants.sort, c::A, c.autoload?(:B)
d = c.dup
p d.constants.sort, d::A
d.const_set(:Z, 26)
p d.constants.sort, c.constants.sort

# nested: only the direct constants are the copy's own
module Outer
  X = 1
  module Inner
    Y = 2
  end
end
o = Outer.clone
p o.constants.sort, o::X, o::Inner::Y, o::Inner.equal?(Outer::Inner)

# a class given a constant in its body, and one given none
k = Class.new { const_set(:Q, 2) }
p k.dup::Q, k.clone.constants
e = Class.new
p e.clone.constants, e.dup.constants

# the copies survive a collection, and so do their constants
copies = Array.new(50) { |i| x = Module.new; x.const_set(:N, i); x.clone }
GC.start
p copies.map { |x| x::N }.sum
p Array.new(2000) { Module.new.clone }.size
GC.start
q = Module.new
q.const_set(:W, :w)
p q.clone::W
