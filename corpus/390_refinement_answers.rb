# A refine body's constant lands on the module around it (with a warning on
# stderr), a refined String#chop! wins over the builtin even when refined
# after `using`, a refinement's method binds only to what it refines, and a
# block handed to a `&:sym` proc goes on to the method

module RfM
  refine String do
    FOO = 123
  end
end
p RfM::FOO

module RfT
  refine(String) do
  end
end
using RfT
def rf_t = "Refinements are broken!".dup.chop!
p rf_t
module RfT
  refine(String) do
    def chop! = sub!(/broken/, "fine")
  end
end
p rf_t

a = Class.new { def foo = :a }
b = Class.new
bar = Module.new { break refine(a) { def foo = super } }
begin
  bar.instance_method(:foo).bind(b.new)
rescue TypeError => e
  p e.class
end
p bar.instance_method(:foo).bind(a.new).call

module RfEmpty
  refine Class.new do
  end
end
class RfC; def call(v, x, &blk) = blk.call(v, &x); end
r = nil
x = ->(z) { r = z }
p RfC.new.call(42, x, &:tap), r
using RfEmpty
r = nil
p RfC.new.call(43, x, &:tap), r
p [1, 2].map(&:to_s), [[1, 2]].map(&:first), [3, 4].inject(&:+)
