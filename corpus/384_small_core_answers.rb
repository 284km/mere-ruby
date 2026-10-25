# What FrozenError, NameError, Data, alias, defined? and Math answer in the
# corners their own test files ask about

def addr(s) = s.gsub(/0x\h+/, "X")

# FrozenError: the class as ruby prints it, and the receiver it was refused on
k = Class.new
begin; k.new.freeze.instance_variable_set(:@a, 1); rescue => e; puts addr(e.message); end
s = Object.new; def s.x; end; s.freeze
begin; s.instance_variable_set(:@a, 1); rescue => e; puts addr(e.message); end
class FrD; end; FrD.freeze
begin; FrD.class_eval { def y; end }; rescue => e; puts e.message; p e.receiver; end
o = Object.new.freeze
begin; o.singleton_class.class_eval { def x; end }; rescue => e; puts addr(e.message); p e.receiver.equal?(o); end
begin; def o.q; end; rescue => e; p e.class, e.receiver.equal?(o); end
begin; o.singleton_class.const_set(:A, 2); rescue => e; puts addr(e.message); p e.receiver.equal?(o.singleton_class); end
begin; FrozenError.new.receiver; rescue => e; p e; end
begin; FrozenError.new("m").receiver; rescue => e; p e; end
p FrozenError.new("m", receiver: 3).receiver

# NameError: what was not found, where, with what
class FrPO < BasicObject; def m; Object; end; end
begin; FrPO.new.m; rescue ::NameError => e; p e.name, e.message; end
begin; FrPO.new.instance_eval("Object"); rescue ::NameError => e; p e.name; end
begin; BasicObject::X; rescue NameError => e; p e.receiver, e.name; end
n = Object.new
begin; n.foo(1, 2); rescue NoMethodError => e; p [e.args, e.private_call?]; end
begin; n.instance_eval { foo(1, 2) }; rescue NoMethodError => e; p [e.args, e.private_call?]; end
def n.method_missing(*) = super
begin; n.bar(3); rescue NoMethodError => e; p [e.args, e.private_call?]; end
begin; n.instance_eval { bar(3) }; rescue NoMethodError => e; p [e.args, e.private_call?]; end
begin; 1.zz; rescue NoMethodError => e; p [e.args, e.private_call?]; end
def lv_t(a, b = nil, *c, &d); e = a; 1.times { |f| g = foo; g }; e; end
begin; lv_t(3); rescue NameError => e; p e.local_variables.sort; end

# Data: any Symbol is a member, the values are not instance variables
D1 = Data.define(:a, :b)
x = D1.new(a: 1, b: "s")
p x.instance_variables, Marshal.load(Marshal.dump(x)) == x
p Data.define(:@a).new(1), Data.define.new, Data.define(:a, :b?, :C).new(1, 2, 3)
D2 = Data.define; p D2.new
p D1.new(1, 2).dup.frozen?, D1.new(1, 2).clone(freeze: false).frozen?
[0, :x=].each { |m| begin; Data.define(m); rescue => e; p e; end }
begin; Data.define(:x, :x); rescue => e; p e; end
p D1.respond_to?(:define), Data.define("y").members
case x
in {a: 1, b:} then p b
end

# alias: an undef stops super, dynamic names, the sender, a zsuper entry
class Al0; def foo = "foo"; end
class Al1 < Al0; alias bar foo; def foo = "foo+#{super}"; end
class Al2 < Al1; alias baz foo; undef foo; end
class Al3 < Al2; def foo = super; def bar = super; end
begin; Al3.new.foo; rescue NoMethodError => e; p e.message; end
p Al3.new.bar
str = "abc"
class << str; alias_method :try, :__send__; end
p str.try(:upcase)
ac = Class.new { def foo = :ok; def bar = :ng; private :foo }
p Class.new(ac) { public :foo; alias bar foo }.new.bar
class AlK
  3.times do |i|
    define_method(:"f_#{i}") { i }
    alias :"g_#{i}" :"f_#{i}"
  end
end
p AlK.new.g_2
begin; Module.new { private :class }.alias_method :xyz, :class; rescue NameError => e; puts addr(e.message); end

# defined?: match variables, calls not made, statements, inherited autoloads
/a/ =~ ''
p [defined?($&), defined?($+), defined?($1)]
/a/ =~ 'a'
p [defined?($&), defined?($+), defined?($1)]
/(a)/ =~ 'a'
p [defined?($&), defined?($+), defined?($1), defined?($2)]
p defined?("x".reverse(1)), defined?("x".reverse(1).reverse), defined?(1.to_i("x"))
p defined? (;zork), defined? (zork;)
zork = 1
p defined? (;zork)
class DfS; autoload :A, "no_such_file"; end
class DfSub < DfS; def a? = defined?(A); end
p DfSub.new.a?
class DfRC; end
module DfRM
  refine DfRC do
    def pub; end
    private def priv; end
  end
  def self.without(x = DfRC.new) = defined?(x.pub)
  using self
  def self.with(x = DfRC.new) = [defined?(x.pub), x.instance_eval { defined?(priv) }]
end
p DfRM.without, DfRM.with

# Math: the sign of a root, the base's domain, a redefined to_f
p Math.sqrt(-0.0).to_s
begin; Math.log(1.0, -1.0); rescue Math::DomainError => e; p e.message; end
Integer.class_eval do
  alias _to_f to_f
  def to_f = (self + 1)._to_f
end
p Math.cos(0), Math.exp(0)
Integer.class_eval { undef to_f; alias to_f _to_f; undef _to_f }
Integer.class_eval do
  alias _to_f to_f
  def to_f = (self << 1)._to_f
end
p Math.log(1 << 64) == Math.log((1 << 65)._to_f)
Integer.class_eval { undef to_f; alias to_f _to_f; undef _to_f }
p 3.to_f, Math.cos(0)
