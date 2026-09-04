# `super` is how a method_missing says "not mine". Every well-written one ends
# in it, and BasicObject#method_missing is what it reaches: that one raises,
# naming the method it was asked for. Answering `super` by calling
# method_missing again is a loop -- it cost 10 GB and a stack overflow, and
# core/method/call_spec.rb reached 12 GB entirely because of it.
class K
  def method_missing(m, *a); m == :ok ? :handled : super; end
  def respond_to_missing?(m, p = false); m == :ok || super; end
end
k = K.new
p k.ok
p [k.respond_to?(:ok), k.respond_to?(:nope), k.respond_to?(:to_s)]
begin; k.nope; rescue NoMethodError => e; p [:nme, e.message]; end
begin; k.nope(1, 2); rescue NoMethodError => e; p [:with_args, e.message]; end
# the name it raises about is the one asked for, not "method_missing"
class Base; def method_missing(m, *a); super; end; end
begin; Base.new.zip_zap; rescue NoMethodError => e; p [:base, e.message]; end
# a chain: each link handles its own and passes the rest up
class P; def method_missing(m, *a); m == :p ? :from_p : super; end; end
class C < P; def method_missing(m, *a); m == :c ? :from_c : super; end; end
p [C.new.c, C.new.p]
begin; C.new.q; rescue NoMethodError => e; p [:chain, e.message]; end
# through a module in the ancestry
module M; def method_missing(m, *a); m == :mm ? :from_m : super; end; end
class D; include M; end
p D.new.mm
begin; D.new.zz; rescue NoMethodError => e; p [:mod, e.message]; end
# a Method object taken through respond_to_missing? still calls method_missing
class E
  def respond_to_missing?(m, p = false); m == :via || super; end
  def method_missing(m, *a); m == :via ? [:via, a] : super; end
end
e = E.new
p e.method(:via).call(1, 2)
p e.respond_to?(:via)
# and the real method wins over method_missing when one exists
class F; def method_missing(m, *a); :missed; end; def real; :real; end; end
p [F.new.real, F.new.unreal]
