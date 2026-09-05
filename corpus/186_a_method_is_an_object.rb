# A Method and an UnboundMethod are objects that describe another method: what
# it is called, where it lives, what it takes, where it was written -- and they
# are callable, composable and comparable like any other object.

class Parent
  def greet(name, greeting = "hi", *rest, loud: false, **opts, &blk)
    [name, greeting, rest, loud, opts]
  end
  def who; :parent; end
  private def secret; :secret; end
end
class Child < Parent
  def who; :child; end
end
module Helper
  def helped; :helped; end
end
class WithHelper
  include Helper
end

m  = Parent.new.method(:greet)
um = Parent.instance_method(:greet)
mc = Child.new.method(:who)

# what it knows
p m.name, m.owner, m.receiver.class, m.arity, m.parameters
p um.name, um.owner, um.arity, um.parameters
p m.source_location.last.is_a?(Integer), um.source_location.first.end_with?(".rb")

# how it writes itself: owner, name, the parameter SHAPE, and where
puts m.inspect.sub(%r{ /\S+\z}, "")
puts um.to_s.sub(%r{ /\S+\z}, "")
puts WithHelper.instance_method(:helped).to_s.sub(%r{ /\S+\z}, "")
p m.inspect == m.to_s

# calling it, by every name ruby gives that
p m.call("a"), m[("b")], m.===("c")
p Parent.new.method(:secret).call
p um.bind(Parent.new).call("d"), um.bind_call(Parent.new, "e")
p m.unbind.class, m.unbind.bind_call(Parent.new, "f")

# ...and composing it, which is the Proc surface reached through #to_proc
p m.to_proc.class, m.to_proc.lambda?, m.to_proc.call("g")
p (m >> ->(r) { r.first.upcase }).call("h")
p (m << ->(x) { x + "!" }).call("i")
p Parent.new.method(:who).curry.call
p Parent.instance_method(:greet).bind(Parent.new).curry[1]

# a Method holds the definition it was TAKEN from, so super_method calls that
p mc.call, mc.super_method.call, mc.super_method.owner
p Parent.new.method(:who).super_method
p Child.instance_method(:who).super_method.owner

# equality and hashing: same receiver, same definition -- and two aliases of
# one method are one method
class Aliased
  def original(x); x; end
  alias first original
  alias second first
end
a = Aliased.new
p a.method(:original) == a.method(:first), a.method(:original).hash == a.method(:first).hash
p a.method(:second).original_name, Aliased.instance_method(:second).original_name
p a.method(:original) == Aliased.new.method(:original)
p Aliased.instance_method(:original) == Aliased.instance_method(:first)
p Method.instance_method(:===) == Method.instance_method(:call)
p Method.instance_method(:[]) == Method.instance_method(:call)

# a copy is a new object: clone carries the frozen status over, dup drops it
mf = Parent.new.method(:who).freeze
p mf.frozen?, mf.clone.frozen?, mf.dup.frozen?, mf.dup.call
uf = Parent.instance_method(:who).freeze
p uf.frozen?, uf.clone.frozen?, uf.dup.frozen?
p mf.dup.equal?(mf), mf.dup == mf

# a builtin module's methods are reachable the same way
p Comparable.instance_method(:clamp).bind_call(5, 1, 3)
p Comparable.instance_method(:between?).bind_call(5, 1, 9)
p m.respond_to?(:curry), m.respond_to?(:call), m.respond_to?(:nope)
p um.respond_to?(:bind_call), um.respond_to?(:nope)
