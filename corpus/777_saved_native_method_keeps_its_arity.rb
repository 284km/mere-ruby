# A Method or UnboundMethod made of a builtin keeps the builtin's arity and
# parameters after a Ruby def replaces the name (issue #133), and the
# definition hooks report theirs
saved_len = Array.instance_method(:length)
saved_push = Array.instance_method(:push)
saved_inc = Module.instance_method(:included)
bound_len = [1, 2].method(:length)
plus = 1.method(:+)
class Array
  def length(a, b = nil) = :ruby
  def push(x) = :ruby_push
end
class Module
  def included(a, b, c = 1) = nil
end
class Integer
  def +(a, b) = :plus2
end
p [saved_len.arity, saved_len.parameters, saved_len.owner]
p [saved_push.arity, saved_push.parameters]
p [saved_inc.arity, saved_inc.parameters]
p [bound_len.arity, bound_len.parameters, bound_len.call]
p [plus.arity, plus.parameters, plus.call(2)]
rebound = saved_len.bind([1, 2, 3])
p [rebound.arity, rebound.parameters, rebound.call]
p [rebound.unbind.arity, rebound.unbind.parameters]
cur = Array.instance_method(:length)
p [cur.arity, cur.parameters]
p [[].method(:length).arity, Integer.instance_method(:+).arity]
class Foo; def bar(a) = a; end
m = Foo.instance_method(:bar)
class Foo; def bar(a, b, c) = a; end
p [m.arity, m.parameters, Foo.instance_method(:bar).arity]
%i[included extended prepended method_added method_removed method_undefined const_added].each { |m| p [m, Module.instance_method(m).arity, Module.instance_method(m).parameters] }
p [:inherited, Class.instance_method(:inherited).arity, Class.instance_method(:inherited).parameters]
p [:singleton_method_added, BasicObject.instance_method(:singleton_method_added).arity]
