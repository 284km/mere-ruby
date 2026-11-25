# A class defined inside an object's singleton class is an ordinary class: a
# subclass or a constant keeps it after the object is collected, with its
# methods, its superclass and what it includes. Its name prints through the
# singleton, never as a bookkeeping key.
class Base1062; end
module Mo1062; def mo = :mo; end

def make_n1062
  o = Object.new
  o.singleton_class.class_eval <<~R
    class N < Base1062
      include Mo1062
      def v = 1
      define_method(:b) { :b }
      X = 7
      def x = X
    end
  R
  o.singleton_class.const_get(:N)
end

whole = ->(c) do
  k = c.new
  [k.v, k.b, k.mo, k.x, c.superclass.superclass, c.ancestors.include?(Mo1062)]
rescue NoMethodError, NameError => e
  e.class
end

20.times { |i| Object.const_set(:"Keep1062_#{i}", Class.new(make_n1062)) }
10.times { |i| eval "class Named1062_#{i} < make_n1062; end" }
held = make_n1062
subs = (1..50).map { Class.new(make_n1062) }
3.times { Array.new(20000) { Object.new }; GC.start }

p whole[Keep1062_3]
p whole[Named1062_7]
p (0...20).count { |i| whole[Object.const_get(:"Keep1062_#{i}")] == [1, :b, :mo, 7, Base1062, true] }
p (0...10).count { |i| whole[Object.const_get(:"Named1062_#{i}")] == [1, :b, :mo, 7, Base1062, true] }
p subs.count { |c| whole[c] == [1, :b, :mo, 7, Base1062, true] }
p [held.new.v, held.new.x, held.superclass]

# the shape of a name: no internal key, the singleton's text, then the path
def shape1062(x)
  t = x.to_s
  [t.include?("(sng:"), t.start_with?("#<Class:"), t[/::\w+\z/], t.count("<") == t.count(">")]
end
o = Object.new
class << o
  class M; end
end
m = o.singleton_class::M
# a class inside the singleton of a class inside a singleton
class << m
  class N2; def hi = :n2; end
end
n2 = m.singleton_class::N2
p shape1062(m.name), shape1062(n2.name), shape1062(n2.inspect), shape1062(n2.to_s)
begin
  n2.new.nope
rescue NoMethodError => e
  p shape1062(e.message[/#<.*\z/])
end
p n2.new.hi
# an instance's own singleton class names the instance's class, not its key
a = m.new
def a.extra = 1
p shape1062(a.singleton_class.inspect)
p a.singleton_class.inspect.include?("::M:0x")
p n2.new.singleton_class.inspect.include?("::N2:0x")

# Module#name answers the same on every path: the ordinary call, Module#name
# bound to the class, and `super` from the class's own `name`. It is the same
# frozen String each time, as any class's name is.
o2 = Object.new
class << o2
  class M; end
  class W; end
end
k = o2.singleton_class::M
p Module.instance_method(:name).bind_call(k) == k.name
p shape1062(Module.instance_method(:name).bind_call(k))
p [k.name.frozen?, k.name.equal?(k.name)]
w = o2.singleton_class::W
def w.name = "named:" + super
p w.name.start_with?("named:#<Class:"), w.name.include?("(sng:"), w.name.end_with?("::W")
p Module.instance_method(:name).bind_call(w) == w.name.delete_prefix("named:")
