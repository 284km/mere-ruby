# ruby's own delegate.rb, shipped as it is: a copy of Kernel that loses names
# without Kernel losing them, SimpleDelegator and DelegateClass forwarding,
# the operators and #inspect a Delegator undefines (they reach
# method_missing), freezing, and the reflection DelegateClass answers.
require "delegate"

def try410
  yield
rescue StandardError => e
  [e.class, e.message]
end

k = Kernel.dup
p k.equal?(Kernel)
k.class_eval { undef_method :format }
p format("%03d", 7), respond_to?(:require, true)

s = SimpleDelegator.new([3, 1, 2])
p s.size, s.sort, s.__getobj__.class, s
p s === [3, 1, 2], (SimpleDelegator.new(5) <=> 7), s == [3, 1, 2], s.eql?(s)
p "#{SimpleDelegator.new(:sym)}", [SimpleDelegator.new(1)]
s.__setobj__("str")
p s.upcase, s.methods.include?(:upcase), s.respond_to?(:upcase)

f = SimpleDelegator.new(+"x")
f.freeze
p f.frozen?, try410 { f.__setobj__(+"y") }.first, try410 { f.upcase! }

class Parent410
  def pub = :pub
  protected def prot = :prot
  private def priv = :priv
end
class Child410 < DelegateClass(Parent410); end
class Parent410
  def added = :added
end
c = Child410.new(Parent410.new)
p c.pub, c.added
ignores = Object.public_instance_methods | Delegator.public_instance_methods
p (Child410.public_instance_methods - ignores).sort
p Child410.instance_method(:added).class, try410 { c.priv }.first
d = DelegateClass(Array) { alias_method :head, :first }
p d.new([9, 8]).head
