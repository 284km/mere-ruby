# Class.new / Module.new with a block of one declaration: one def, `using X`
# and one def, and `refine X` with a block of one def. The ISeq VM reads such a
# block's program as the parsed form and defines straight into the new class
# (vm_def_block_body); what is compared is what the definitions mean.
$c = Class.new do
  def foo = :plain
end
p $c.new.foo, $c.instance_method(:foo).source_location[1]
$m = Module.new do
  refine $c do
    def foo = :refined
  end
end
k = Class.new do
  using $m
  def initialize
    @r = $c.new.foo
    @u = $c.new.method(:foo).unbind.bind_call($c.new)
  end
  attr_reader :r, :u
end
o = k.new
p o.r, o.u, $c.new.foo
p k.instance_method(:initialize).source_location[1]
p $m.refinements.size, $m.refinements[0].instance_method(:foo).source_location[1]
# a local as the argument
mod = $m
k2 = Class.new { using mod; def bar = $c.new.foo }
p k2.new.bar
# the block's value and a class with a superclass
p(Class.new(Array) { def x = 1 }.new.x)
# visibility: initialize is private, as with the walker
p k.private_instance_methods(false)
# a def named as a hook keeps the walker
h = Class.new { def method_added(n) = nil }
p h.instance_methods(false)
# the def's end line
z = Class.new do
  def multi(a, b = 2)
    a + b
  end
end
p z.new.multi(1), z.instance_method(:multi).parameters
# a block that is more than one declaration runs as before
w = Class.new do
  def a = 1
  def b = 2
end
p w.instance_methods(false).sort
# Module.new with one def, and its methods' owner
mm = Module.new { def mx = :mx }
p Class.new { include mm }.new.mx, mm.instance_method(:mx).owner == mm
# the class's own inherited hook still runs before the def
base = Class.new { def self.inherited(s) = (puts "inherited #{s.instance_methods(false).inspect}") }
p Class.new(base) { def y = 2 }.new.y
# a class whose new ignores the block: the block's def is never made
class Ign
  def initialize; end
end
Ign.new { def never_made; end }
p Ign.method_defined?(:never_made), Object.method_defined?(:never_made)
