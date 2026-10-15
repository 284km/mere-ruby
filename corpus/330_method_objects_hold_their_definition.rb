# A Method or UnboundMethod holds the definition it was made from (note 354):
# a later def, remove_method or undef_method of the name does not change it,
# and neither does a refinement activated after a builtin's Method was taken.

# ---- 1. redefinition, removal, undef, publication, refinement, define_method
class Base; def foo = :base_foo; end
class Derived < Base; def foo = :derived_foo; end
m = Derived.new.method(:foo)
um = m.unbind
um2 = Derived.instance_method(:foo)
class Derived; def foo = :redefined; end
p m.call, um.bind(Derived.new).call, um2.bind_call(Derived.new), Derived.new.foo
class Derived; remove_method :foo; end
p m.call, um.bind(Derived.new).call, Derived.new.foo
# a method object survives undef too
class U; def x = 1; end
mx = U.new.method(:x); U.send(:undef_method, :x)
p mx.call, (U.new.x rescue $!.class)
# super from a captured method still goes up from its own owner
class P1; def s = :p1; end
class C1 < P1; def s = [:c1, super]; end
ms = C1.new.method(:s)
class P1; def s = :p1_new; end
class C1; def s = :c1_new; end
p ms.call
# zsuper method object
class ZB; def z(a) = [:zb, a]; end
class ZD < ZB; public :z; end
mz = ZD.new.method(:z)
class ZB; def z(a) = [:zb_new, a]; end
p mz.call(1)
# refinement captured before using
module MP; refine Integer do; def pow(*) = :refine_pow; end; end
meth = 2.method(:pow)
module MQ; using MP; def self.t(m) = m.call(3); end
p MQ.t(meth)
# define_method from a captured method
class DM; def a = :a1; end
MA = DM.instance_method(:a)
class DM; def a = :a2; define_method(:b, MA); end
p DM.new.b
# to_proc of a captured method
class TP; def t = :t1; end
pr = TP.new.method(:t).to_proc
class TP; def t = :t2; end
p pr.call
# Method#owner/source_location after redefinition
p m.owner, um.owner

# ---- 2. what such an object answers about its definition --------------
class A2; private; def foo(arg = nil) = 1; end
class B2 < A2; public :foo; end
unbound = B2.instance_method(:foo)
p unbound.parameters, unbound.arity
A2.send(:remove_method, :foo)
p unbound.parameters, unbound.arity, unbound.inspect.sub(/ \S+:\d+>$/, ">"), unbound.bind_call(B2.new)
p B2.instance_methods(false).include?(:foo)
p((B2.instance_method(:foo) rescue $!.class))
class A0; def foo(a1 = nil, a2 = nil) = 0; end
a0_foo = A0.instance_method(:foo)
class A1 < A0; private; def foo(arg = nil) = 1; end
class B1 < A1; public :foo; end
u1 = B1.instance_method(:foo)
p u1.super_method == a0_foo
A1.send(:remove_method, :foo)
p u1.inspect.sub(/ \S+:\d+>$/, ">"), u1.parameters, u1.super_method == a0_foo, u1.bind_call(B1.new)
class R; def r(x) = x; end
mr = R.new.method(:r)
class R; def r(x, y) = y; end
p mr.arity, mr.parameters, mr.call(5)
