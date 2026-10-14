# Methods as test_method asks them (note 347).
def t(name)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0, 70]}"; end
  puts "#{name}: #{r}"
end

# a builtin's #initialize is a method of the class
t(:ary_init) { [Array.instance_method(:initialize).arity, Array.instance_method(:initialize).parameters, Object.instance_method(:initialize).owner] }

# super_method walks the ancestors of the class it was asked of
class Base; def foo() :base end; end
class Derived < Base; def foo() :derived end; end
m1 = Module.new { def foo; end }
c1 = Class.new(Derived) { include m1; def foo; end }
t(:super_chain) { m = c1.instance_method(:foo); r = []; 5.times { r << (m && (m.owner == c1 ? :c1 : m.owner == m1 ? :m1 : m.owner)); m = m&.super_method }; r }

# a Method's proc has the method's lexical scope
class CC; DD = "Const_D"; def foo; end; end
t(:to_proc_cref) { b = CC.new.method(:foo).to_proc.binding; [b.local_variables, b.eval("DD")] }

# (self).m is not a private call
class V
  private def mv2 = 1
  def go = [self.mv2, ((self).mv2 rescue $!.class), (self) == self]
end
t(:paren_self) { V.new.go }

# a name that is not a name, in the receiver's inspect
cx = Class.new { def self.inspect = "Xcat" }
t(:bad_name_method) { Object.new.method(cx) }
t(:bad_name_dm) { Class.new { define_method(cx) {} } }
t(:bad_name_dm2) { Class.new.send(:define_method, cx) {} }

# the parenthesised owner is where the body is
c = Class.new; c.class_eval { def foo; end }
c2 = Class.new(c); c2.class_eval { private :foo }
t(:zsuper_inspect) { c2.new.method(:foo).inspect.gsub(/0x\h+/, "X").sub(/ \S+:\d+>/, ">") }

# def O.m in class << O, with O an object constant, is public and O's
OO = Object.new
class << OO
  private
  def OO.a = 1
  def b = 2
  def OO.def; end
end
t(:sdef_object) { [OO.a, (OO.b rescue $!.class), OO.def, OO.singleton_methods.sort] }

# an operator's Method calls the operator, comparisons included
t(:op_call) { m = 0.method(:<); [m.call(5), m === 5, m === -5, 0.method(:==).call(0), 1.0.method(:<).call(5), "a".method(:+).call("b")] }

# a copy or an unbound copy walks the same ancestors
bm1 = Module.new { def foo; end }
bm2 = Module.new { def foo; end }
bc = Class.new { include bm1; include bm2 }
t(:clone_super) { m = bc.new.method(:foo); sim = bc.instance_method(:foo).super_method; [m.unbind.super_method == sim, m.unbind.clone.super_method == sim, sim.owner == bm1] }

# a builtin listed by instance_methods can be taken
t(:enum_method) { [Enumerable.instance_method(:each_slice).owner, Enumerable.instance_method(:each_slice).bind_call([1, 2, 3], 2).to_a] }

# an object constant read through the scope a singleton body was opened in
class TM
  PST = Object.new
  class << PST
    private
    PST.define_singleton_method(:dsm) {}
    def PST.def; end
  end
  def self.go = [PST.dsm, PST.def]
end
t(:nested_sdef) { TM.go }

# an alias in a subclass names the class it came from
c3 = Class.new(c); c3.class_eval { alias bar foo }
t(:alias_inspect) { c3.new.method(:bar).inspect.gsub(/0x\h+/, "X").sub(/ \S+:\d+>/, ">") }

# a def run in a singleton method lands in the class it was written in, one
# in a method made by instance_eval stays on the singleton, and one run in a
# top-level method is public
class DN
  T = Object.new
  def T.dm; def im = self; end
  IE = Object.new
  IE.instance_eval { def iem; def ie_body = 1; end }
end
DN::T.dm
DN::IE.iem
X9 = Object.new
def X9.m; def tl_im = 7; end
X9.m
t(:nested_defs) { [DN.method_defined?(:im, false), DN::T.respond_to?(:im), DN::IE.respond_to?(:ie_body), DN.method_defined?(:ie_body), X9.respond_to?(:tl_im)] }
