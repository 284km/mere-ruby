# Four things the CRASH pass of 2026-09-03 added, kept honest by ruby: an
# arithmetic sequence is an Enumerator that knows its bounds; "#@x" interpolates
# without braces; define_singleton_method takes a Method/UnboundMethod/Proc; and
# __callee__ answers the alias it was called by, also through send.
a = 1.step(10)
p a.class, a.class.superclass, a.is_a?(Enumerator)
p a.to_a, a.size, a.last, a.last(2), a.first(3)
p [a.begin, a.end, a.step, a.exclude_end?]
p a
b = (1..10).step(3)
p b.class, b.to_a, b.size, b.last, b
c = (1...10).step(3)
p c.to_a, c.size, c.exclude_end?, c
d = 1.step(10, 3)
p d.to_a, d.inspect
e = 1.step(by: 2, to: 10)
p e.to_a, e.inspect, e.begin, e.end, e.step
p 1.step(10) == 1.step(10), 1.step(10) == 1.step(10, 2), 1.step(10).hash == 1.step(10).hash
r = []
p(1.step(7, 2).each { |i| r << i }.class)
p r
p 10.step(1, -3).to_a, 10.step(1, -3).size, 10.step(1, -3).last
p 1.step(10, 3).map { |x| x * 2 }
p (1..).step(5).first(3), (1..).step(5).size

@x = "ex"; $y = "why"
class Q; @@z = "zed"; def s; "#@@z!"; end; end
p "#@x", "#$y", Q.new.s, "a#@x c", "#@", "x #$ y", "#@x#@x"
class C1; def self.constants_like; :c; end; end
class DefineSingletonMethodSpecClass
  define_singleton_method(:another_test_method, self.method(:constants))
  def self.plain; :plain; end
end
p DefineSingletonMethodSpecClass.another_test_method.class
class Parent; def self.pcm; :pcm; end; end
um = Parent.method(:pcm).unbind
class Child < Parent; end
Child.send :define_singleton_method, :child_class_method, um
p Child.child_class_method
DefineSingletonMethodSpecClass.define_singleton_method(:from_proc, proc { |a| a * 2 })
p DefineSingletonMethodSpecClass.from_proc(21)
class Callee; def from_send; send(:__callee__); end; def direct; __callee__; end; alias_method :ali, :direct; end
p Callee.new.from_send, Callee.new.direct, Callee.new.ali
