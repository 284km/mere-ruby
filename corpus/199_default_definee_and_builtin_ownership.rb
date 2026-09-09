# Where a bare `def` goes, and who answers when a reopened Object and a
# builtin both have the name.
#
# `def` writes to the DEFAULT DEFINEE, which is not "the class of self":
# instance_eval / instance_exec move it to the receiver's SINGLETON class, and
# `alias` and `undef` read the same thing. Reading self alone put every `def`
# written inside an instance_eval on the object's CLASS.

class A
  def value; 5; end
  def self.km; 7; end
end

o = A.new
o.instance_exec { def d1; :d1; end }
p [o.d1, A.new.respond_to?(:d1, true), o.singleton_methods.sort]

# the string form takes the same route
o.instance_eval("def d2; :d2; end")
p [o.d2, A.new.respond_to?(:d2, true)]

# `alias` and `undef` inside an instance_eval are the object's alone
o.instance_eval { alias __v value }
p [o.__v, A.new.respond_to?(:__v)]
o.instance_eval { undef value }
p [o.respond_to?(:value), A.new.value]

# instance_eval on a CLASS defines CLASS methods; class_eval defines instance
# methods. Both were class-body runs with the same definee.
A.instance_eval { def cm; :cm; end }
A.class_eval    { def im; :im; end }
p [A.cm, A.new.im, A.new.respond_to?(:cm), A.respond_to?(:im)]

A.instance_exec { alias __k km }
p [A.__k, Object.respond_to?(:__k)]

# the _exec forms pass their arguments to the block; the _eval forms take none
p [A.class_exec(1) { |x| x + 1 }, A.instance_exec(2) { |x| x * 3 }]
begin
  A.class_eval(4) { 0 }
rescue ArgumentError => e
  puts "class_eval(4): #{e.message}"
end

# A top-level `def` is a PRIVATE instance method of Object -- which is why a
# bare call works from inside any class -- and a bare `public` switches the
# mode for the ones that follow.
def top_priv(a); a * 2; end
public
def top_pub; :pub; end
private
def top_priv2; :p2; end

class Z; def use; top_priv(3); end; end
p [Z.new.use, Z.new.send(:top_priv, 4), Z.new.respond_to?(:top_priv, true), Z.new.respond_to?(:top_priv)]
p [Object.private_instance_methods(false).include?(:top_priv),
   Object.public_instance_methods(false).include?(:top_pub),
   Object.private_instance_methods(false).include?(:top_priv2)]

# ...and a BUILTIN the receiver's own class owns still answers first. The
# ancestor walk cannot see builtins (they have no method-table entry), so a
# root entry used to outrank every subclass primitive: this made [1,2].size,
# {a: 1}.size, "ab".size and 5.size all answer 99.
class Object
  def size; 99; end
  def upcase; :from_object; end
end
p [[1, 2].size, {a: 1}.size, "ab".size, 5.size, "ab".upcase]
# a name no builtin owns still reaches the reopened Object
p [[1, 2].upcase, Object.new.size]

# Rational and Complex are Numerics, and none of these five is allocated
p [Rational(1, 2).is_a?(Numeric), Rational(1, 2).is_a?(Comparable),
   Complex(1, 2).is_a?(Numeric), Rational.ancestors.include?(Comparable)]
%w[Rational Complex Symbol Integer Float].each do |n|
  k = Object.const_get(n)
  a = (k.new(1) rescue $!.class)
  b = (k.allocate rescue $!.class)
  puts "#{n}: new=#{a} allocate=#{b}"
end
