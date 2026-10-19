# Modules as test_module asks (note 381): alias_method after a respond_to?
# (the method caches hear of it); attr_* inside instance_eval defines on the
# receiver, publicly; define_method takes the scope's visibility, keeps the
# initializers private and gives `it` / `_1` bodies their arguments in every
# form; an inherited const_missing answers `c2::Bar`; a String name that is
# invalid in its encoding is an EncodingError; nested temporary names follow
# the owner's, and clearing it clears them; a module a prepended module
# includes later is not added where the chain already has it; and attr_*
# statements check their names, answer them, warn about the old boolean, and
# run inside blocks of a class body.
c = Class.new { def foo = :foo }
o = c.new
p o.respond_to?(:bar)
p c.class_eval { alias_method :bar, :foo }, o.respond_to?(:bar), o.bar

k = Class.new
k.instance_eval { attr_reader :x }
p k.instance_methods(false), k.singleton_methods
k2 = Class.new
k2.instance_eval { private; attr_reader :y }
p k2.instance_methods(false), k2.private_instance_methods(false), k2.new.instance_eval { y }

class Y357
  def a; end
  private def b; end
  define_method(:b, instance_method(:b))
  define_method(:c, instance_method(:a))
  private
  define_method(:a, instance_method(:a))
end
p Y357.public_instance_methods(false).sort, Y357.private_instance_methods(false).sort
class Z357
  define_method(:initialize) { @x = 1 }
  define_method(:f) { it * 2 }
  define_method(:g) { _1 + _2 }
end
p Z357.private_instance_methods(false), Z357.new.instance_variable_get(:@x), Z357.new.f(3), Z357.new.g(1, 2)

c1 = Class.new
c2 = Class.new(c1)
c1.instance_eval { def const_missing(x) = x }
p [c1::Bar, c2::Bar, c2.const_get(:Bar), c2.const_get(:Bar, false)]
[-> { Math.const_get("\xC3") }, -> { Object.const_set("A\xC3", 1) }].each do |f|
  f.call
rescue EncodingError => e
  p e.message
end

m = Module.new
m.const_set(:N, Module.new)
m::N.set_temporary_name("x")
m::N.set_temporary_name(nil)
m::N.const_set(:O, Module.new)
m.const_set(:Recursive, m)
m::N.const_set(:Recursive, m)
p m.set_temporary_name("fake_name").name, m::N.name, m::N::O.name
m::N.set_temporary_name("temp")
p m::N.name, m::N::O.name
m.set_temporary_name(nil)
p m.name, m::N.name, m::N::O.name

def show357(k, names) = k.ancestors.take_while { _1 != Object }.map { names[_1] }
base = Class.new
sub = Class.new(base)
m1 = Module.new
m2 = Module.new
n = { base => :c, sub => :sc, m1 => :m1, m2 => :m2 }
sub.include m2
sub.prepend m1
m1.include m2
p show357(sub, n)
base = Class.new
sub = Class.new(base)
m1 = Module.new
m2 = Module.new
n = { base => :c, sub => :sc, m1 => :m1, m2 => :m2 }
m1.include m2
sub.include m2
sub.prepend m1
p show357(sub, n)

begin
  Class.new.instance_eval { attr_reader :"." }
rescue NameError => e
  p e.message
end
a = Class.new
p a.class_eval { attr :a }, a.class_eval { attr_accessor :k, :l }, a.class_eval { attr_writer :g }
class D357
  [1].each { attr_reader :x }
end
p D357.instance_methods(false)
