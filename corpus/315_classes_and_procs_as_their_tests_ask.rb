# Classes and procs as CRuby's test_class and test_proc ask them (note 337):
# a module_eval string sees the caller's locals, a method copied by clone
# reads the copy's constants, true / false / nil can be extended, a Binding
# has a singleton class of its own, dup / clone of a Proc or a Binding carry
# its instance variables, and `lhs = x rescue y` rescues only the right side
# for an attribute, an index, an ivar and a multiple assignment.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
module Foo315; def foo315 = :foo; end
t(1) { false.extend(Foo315); true.extend(Foo315); nil.extend(Foo315); [false.foo315, true.foo315, nil.foo315, FalseClass.include?(Foo315)] }
class CloneT315; T2 = 1; def foo = TEST; def baz = T2; end
CloneT315a = CloneT315.clone
class CloneT315a; TEST = :C1; end
X315 = CloneT315.dup
X315.const_set(:TEST, 5)
t(2) { [CloneT315a.new.foo, X315.new.foo, CloneT315a.new.baz, (CloneT315.new.foo rescue $!.class)] }
t(3) { c = Class.new.freeze; [Module.new.module_eval("self::Foo = c") == c, Module.new.const_set(:Foo, c) == c] }
t(4) { m = Module.new; c = m.module_eval "class Mx315; new; end"; eval "class C < c; end" }
t(5) { m = Module.new; o = m.module_eval "class Ax315; self; end.new"; o::Foo }
t(6) { b = binding; def b.hi = 1; c = binding; class << c; def ho = 2; end
       [b.hi, b.singleton_methods, b.respond_to?(:hi), c.ho, c.clone.ho, (c.dup.ho rescue $!.class), Object.new.respond_to?(:ho)] }
t(7) { b = proc { binding }.call; class << b; attr_accessor :foo; end; bd = b.dup; [(bd.foo rescue $!.class), (b.foo = :bar), b.clone.foo] }
t(8) { pr = proc { 1 }; class << pr; attr_accessor :foo; end; pr.foo = 5; pr.instance_variable_set(:@a, 3)
       [pr.foo, (pr.dup.foo rescue $!.class), pr.clone.foo, pr.dup.instance_variable_get(:@a), pr.clone.instance_variable_get(:@a)] }
S315 = Struct.new(:v)
t(9) {
  o = S315.new(1)
  o.v = raise("a") rescue 3; r1 = o.v
  o.v += raise("b") rescue 6; r2 = o.v
  h = {k: 1}; h[:k] = raise("c") rescue 4; r3 = h[:k]
  h[:k] += raise("d") rescue 7; r4 = h[:k]
  o.v=(raise("e")) rescue 8; r5 = o.v
  @a315 = raise("f") rescue 9
  a, b = raise("g") rescue [1, 2]
  o&.v = raise("h") rescue 11
  [r1, r2, r3, r4, r5, @a315, a, b, o.v, (1 == raise("i") rescue 12)]
}
