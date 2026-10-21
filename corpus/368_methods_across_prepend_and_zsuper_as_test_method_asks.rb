# Methods across prepend and visibility-only (zsuper) entries, as test_method asks

# prepended_public_zsuper
mod = Module.new { private def foo; [:ok] end }
obj = Object.new.extend(mod)
class << obj; public :foo; end
mod1 = Module.new { def foo; [:mod1] + super end }
obj.singleton_class.prepend(mod1)
mod2 = Module.new { def foo; [:mod2] + super end }
obj.singleton_class.prepend(mod2)
m = obj.method(:foo)
p [m.owner == mod2, m.super_method.owner == mod1, m.super_method.super_method&.owner == obj.singleton_class, m.super_method.super_method&.super_method]
p obj.foo
# super_method_alias_to_prepended_module
pm = Module.new { def m1; [:P_m1] + super end; def m2; [:P_m2] + super end }
c0 = Class.new { def m1; [:C0_m1] end }
c1 = Class.new(c0) { def m1; [:C1_m1] + super end; prepend pm; alias m2 m1 }
o1 = c1.new
p o1.m2
mm = o1.method(:m2)
p mm.call
p [mm.owner == pm, mm.super_method.owner == c1, mm.super_method.name, mm.super_method.original_name]
p mm.super_method.super_method.owner == pm, mm.super_method.super_method.name
# zsuper_method_removed
a = Class.new { private; def foo(arg = nil) = 1 }
b = Class.new(a) { public :foo }
unbound = b.instance_method(:foo)
p unbound == b.public_instance_method(:foo), unbound.parameters, unbound.owner == a
a.remove_method(:foo)
p unbound.parameters
p unbound.bind_call(b.new)
p b.instance_methods(false).include?(:foo)
begin; b.instance_method(:foo); p :noraise; rescue NameError => e; p e.class; end
# singleton_method bug 20620
mx = Module.new { extend self; def foo = :foo }
p mx.singleton_method(:foo).call
begin; mx.singleton_method(:puts); p :noraise; rescue NameError; p :NameError; end
sc = Class.new { def t = :t }
c = Class.new(sc) { singleton_class.prepend(Module.new { def bar = :bar }); extend(Module.new { def quux = :quux }); def self.baz = :baz }
p c.singleton_method(:bar).call, c.singleton_method(:baz).call, c.singleton_method(:quux).call
begin; c.singleton_method(:t); p :noraise; rescue NameError; p :NameError; end
c2 = Class.new(c)
%i[bar baz quux].each { |n| begin; c2.singleton_method(n); p [n, :noraise]; rescue NameError; p [n, :NameError]; end }

pm2 = Module.new { def m1; [:P_m1] + super end; def m2; [:P_m2] + super end }
cx0 = Class.new { def m1; [:C0_m1] end }
cx1 = Class.new(cx0) { def m1; [:C1_m1] + super end; prepend pm2; alias_method :m2, :m1 }
p cx1.new.m2, cx1.new.method(:m2).super_method.owner == cx1, cx1.instance_method(:m2).owner == pm2
c3 = Class.new { def a = 1; alias b a }
p c3.new.b, c3.instance_method(:b).original_name

# a zsuper entry is the class's own: remove_method takes it away
ra = Class.new { private; def foo = 1 }
rb = Class.new(ra) { public :foo }
rb.remove_method(:foo)
p((rb.new.foo rescue $!.class), rb.public_method_defined?(:foo))
p((rb.remove_method(:foo) rescue $!.class))
# ...and with nothing above it any more, it stands for nothing
s1 = Class.new { private def foo; end }
s2 = Class.new(s1) { public :foo }
s3 = Class.new(s2) { def foo; end }
s1.class_eval { undef foo }
p s3.instance_method(:foo).super_method
# super_method through a prepended alias, called
p1 = Module.new { def m1; [:P_m1] + super end; def m2; [:P_m2] + super end }
q0 = Class.new { def m1; [:C0_m1] end }
q1 = Class.new(q0) { def m1; [:C1_m1] + super end; prepend p1; alias m2 m1 }
mm = q1.new.method(:m2)
r = []
while mm
  r << mm.call
  mm = mm.super_method
end
p r
