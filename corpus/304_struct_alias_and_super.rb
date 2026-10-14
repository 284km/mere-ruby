# Struct, alias and super as CRuby's test_struct / test_alias / test_super
# ask them (note 326): a keyword_init struct class says so in its inspect,
# a struct's initialize is (*), a writer's name is no member; a module
# included BEFORE the superclass had it keeps its place in the chain (Bug
# #3351); and an alias of a builtin made in a singleton class or in a module
# an object is extended with answers.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
S304 = Struct.new(:a, keyword_init: true)
t(1) { [S304, S304.to_s, [S304], Struct.new(:a).instance_method(:initialize).parameters, Struct.new(:a).instance_method(:initialize).arity] }
t(2) { Struct.new(:a, :b=) }
module DI304; class Base; def foo = [:Base]; end; module Override; def foo = super << :Override; end
class A < Base; def foo = super << :A; end; class B < A; def foo = super << :B; end
B.send(:include, Override); A.send(:include, Override); end
t(3) { [DI304::B.new.foo, DI304::B.ancestors.take(5)] }
module M304; def m = [:m] + super; end; class P304; def m = [:p]; include M304; end; class C304 < P304; include M304; def m = [:c] + super; end
t(4) { [C304.ancestors.take(4), C304.new.m] }
t(5) { m = Module.new { alias orig_to_s to_s }; o = Object.new.extend(m); q = Object.new; class << q; alias orig_inspect inspect; end; [o.to_s == o.orig_to_s, q.orig_inspect == q.inspect] }
