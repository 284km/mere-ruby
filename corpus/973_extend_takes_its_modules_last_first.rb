# `obj.extend(A, B)` takes its modules LAST FIRST, as rb_obj_extend does: B
# is mixed in and hears #extended, then A. So A is the nearer one, and A's
# method can `super` into B's. They were taken first to last. activerecord's
# `has_many :comments, extend: [NamedExtension, NamedExtension2]` has
# NamedExtension#greeting call super into NamedExtension2's: "hullo :)" read
# "hullo".
module A; def g = super + " :)"; def who = :a; end
module B; def g = "hullo"; def who = :b; end
module C; def who = :c; end
o = Object.new
o.extend(A, B)
p o.g, o.who, o.singleton_class.ancestors[1, 2]
# one at a time, the later one is the nearer
o2 = Object.new
o2.extend(A); o2.extend(B)
p o2.who, o2.singleton_class.ancestors[1, 2]
o3 = Object.new
o3.extend(*[A, B, C])
p o3.who, o3.singleton_class.ancestors[1, 3]
# include and prepend take several the same way
k = Class.new { include A, B }
p k.new.who, k.ancestors[1, 2]
k2 = Class.new { prepend A, B }
p k2.ancestors[0, 2]
# a module, a class, an Enumerator, a String, main
m = Module.new { extend A, B }
p m.who
class K973; extend A, B, C; end
p K973.who, K973.singleton_class.ancestors[1, 3]
r = [1].each
r.extend(A, B)
p r.who
s = +"str"
s.extend(B, A)
p s.who
extend C, A
p who
p (o.extend rescue $!.class)

# the hooks: each module's extend_object and then its extended, last first
$log = []
module H1; def self.extended(b) = ($log << :h1_extended); def self.extend_object(o) = ($log << :h1_eo; super); end
module H2; def self.extended(b) = ($log << :h2_extended); def self.extend_object(o) = ($log << :h2_eo; super); end
module H3; def self.extended(b) = ($log << :h3_extended); end
Object.new.extend(H1, H2, H3)
p $log
$log = []
Object.new.extend(H3, H1)
p $log
$log = []
module P1; def self.extended(b) = ($log << :p1); end
module P2; def self.extended(b) = ($log << :p2); end
Object.new.extend(P1, P2)
p $log

# ONE AT A TIME, the hook included: a module's #extended runs as soon as
# that module is in, before the modules written before it. What the hook
# sees when it calls the receiver is that module's method, not the nearer
# one's that is mixed in next. The order of the hooks alone does not show it.
module HA; def who = :a; end
module HB; def who = :b; def self.extended(o) = ($saw << [o.class, o.who]); end
module HC; def who = :c; def self.extended(o) = ($saw << [:c, o.who, o.singleton_class.ancestors.include?(HA)]); end
[Object.new, [1], { a: 1 }, +"s", proc { }, Module.new, Class.new, [1].each].each do |recv|
  $saw = []
  recv.extend(HA, HB, HC)
  p [$saw, recv.who]
end
$saw = []
one = Object.new
one.extend(HB); one.extend(HA)
p [$saw, one.who]
# a hook that extends again, and reads what its module brought
module HD; def d = :d; def self.extended(o) = (o.extend(HE); ($saw << [:d, o.d, o.respond_to?(:e)])); end
module HE; def e = :e; def self.extended(o) = ($saw << [:e, o.respond_to?(:d)]); end
$saw = []
x = Object.new.extend(HA, HD)
p $saw, x.singleton_class.ancestors[1, 3]
