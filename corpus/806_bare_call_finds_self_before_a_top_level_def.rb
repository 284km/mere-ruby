# A bare call is a call on self. A method the program defined at the top
# level is a private method of Object, so a class (or a module it includes,
# or self's singleton class) that defines the same name comes first -- in a
# method, in a block in it, in a define_method body and its defaults, with
# arguments and with a block. Only where nothing before Object has the name
# does the top-level def answer.

def foo = :top
def foo_b(&b) = [:top, b.call]
def foo_a(x) = [:top, x]
def dflt = 7

module M; def foo = :mod; end
class A
  def foo = :a
  def foo_b(&b) = [:a, b.call]
  def foo_a(x) = [:a, x]
  def m = [foo, foo(), foo_b { 1 }, foo_a(2), [1].map { foo }]
  def self.foo = :a_cls
  def self.cm = foo
end
class B; include M; def m = foo; end
class C; def m = foo; end
class D < A; end
p A.new.m, A.cm, B.new.m, C.new.m, D.new.m, foo

o = Object.new
def o.foo = :sng
def o.m = foo
p o.m

class E; def m = foo; private def foo = :e_priv; end
p E.new.m

module Kernel; def kf = :kernel; end
def kf = :top_kf
class F; def m = kf; end
p F.new.m

class DM
  define_method(:dm1) { |a, b = dflt| [a, b, dflt] }
  define_method(:dm2) { |a, k: dflt| [a, k] }
  def dflt = 9
end
p DM.new.dm1(1), DM.new.dm2(1)

# public_send of a top-level method names main as the receiver
def priv_top = 1
[-> { public_send(:priv_top) }, -> { self.public_send(:priv_top) },
 -> { Object.new.public_send(:priv_top) }].each do |call|
  call.()
rescue NoMethodError => e
  p e.message
end
