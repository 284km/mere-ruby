# A class defined inside an object's singleton class is an ordinary class.
# mere-ruby keys it "(sng:<id>)::M", which starts like the singleton class's
# own key, and several paths took it for one: every def, define_method and
# method_added into it died ("failed"), Class#new refused it as a singleton,
# and it had no name. ActiveSupport's Object#class_eval is
# singleton_class.class_eval, so a test that defines a model with
# `class_eval "class M < ActiveRecord::Base ... end"` landed here (Rails'
# has_many_associations_test, the lazily_evaluates_target_class pair).

o = Object.new
class << o
  class M
    X = 1
    def hi; :hi; end
    def self.s; :s; end
  end
end
k = o.singleton_class.const_get(:M)
p k.new.hi, k.s, k::X
p k.singleton_class?
p o.singleton_class.singleton_class?

# define_method, and method_added on the class itself
# (a class's dup calls method_added for each method it copies in ruby, and
#  not yet in mere-ruby -- for any class: N's hook stays out of the dup below)
class << o
  class N
    def self.method_added(m) = (puts "added #{m}")
  end
end
n = o.singleton_class.const_get(:N)
n.define_method(:dm) { :dm }
n.class_eval { def ev; :ev; end }
p n.new.dm, n.new.ev
p n.instance_methods(false).sort

# its name is its place: the singleton's inspect, then ::N
s = n.name
p [s.class, s.start_with?("#<Class:"), s.end_with?(">::N")]

# a string class_eval on the singleton, as ActiveSupport's Object#class_eval does
module Kernel
  def class_eval(*args, &block)
    singleton_class.class_eval(*args, &block)
  end
end
class Base
  def self.inherited(sub)
    super
    puts "inherited #{sub.name.class} #{sub.name.end_with?("::Model")}"
  end
end
class T
  def go
    class_eval(<<-EOF, __FILE__, __LINE__ + 1)
      class Model < Base
        def hi; :model; end
      end
    EOF
    singleton_class.const_get(:Model)
  end
end
m = T.new.go
p m.new.hi, m.superclass
p m.instance_method(:hi).owner == m

# dup and allocate work on it; the singleton itself still refuses
class << o
  class D
    def dm; :dm; end
  end
end
d = o.singleton_class.const_get(:D)
p d.dup.new.dm
p n.allocate.class == n, n.new.class == n, n.new.is_a?(n)
begin
  o.singleton_class.new
rescue TypeError => e
  p e.message
end
begin
  o.singleton_class.dup
rescue TypeError => e
  p e.message
end

# a frozen object's singleton is still refused a def; the class inside it is not
f = Object.new
class << f
  class Inner; end
end
inner = f.singleton_class.const_get(:Inner)
f.freeze
begin
  f.singleton_class.class_eval { def nope; end }
rescue => e
  p e.class
end
inner.class_eval { def fine; :fine; end }
p inner.new.fine

# constants: its own, the singleton's around it, and a class nested deeper
c = Object.new
class << c
  Y = 2
  class M
    X = 1
    def x = X
    def y = Y
    def self.cy = Y
    class Deep
      def z = [X, Y]
    end
  end
  def mk = M
end
cm = c.singleton_class.const_get(:M)
p cm.new.x, cm.new.y, cm.cy
p cm::Deep.new.z
p cm.const_get(:X), cm.constants.sort, cm.const_defined?(:Y)
p c.mk.equal?(cm), cm.superclass, cm.singleton_class?
p cm.instance_methods(false).sort
p cm.public_method_defined?(:x), cm.new.respond_to?(:y)

# a class under a NAMED class's singleton, opened from outside
class Foo1061; end
class << Foo1061
  class Out
    def o = :o
  end
end
fo = Foo1061.singleton_class.const_get(:Out)
p fo.new.o, fo.new.class == fo, fo.name.end_with?("::Out"), fo.inspect.end_with?("::Out")

# a subclass like any other: listed, in the ancestors, and its instance's
# own singleton class is a new one above it
class Base1061; end
s1 = Object.new
class << s1
  class Sub < Base1061; end
end
sub = s1.singleton_class.const_get(:Sub)
p Base1061.subclasses.include?(sub), sub.ancestors.first == sub, sub.new.is_a?(Base1061)
p sub.new.singleton_class.superclass == sub
