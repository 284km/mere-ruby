# Module as CRuby's test_module asks it (note 319): append_features refuses
# a non-module, class_eval passes the receiver to a splat block, an attribute
# name must be an identifier, const_defined? walks a path (a Symbol is never
# one, a middle that is no module is a TypeError, the later segments are
# asked without Object's top level), a constant holding a value refuses
# `module A` with where it was set, a string *_eval puts the scope back when
# it raises, a constant assignment is the value of a module_eval, the
# visibility of Module's own methods can be changed on a singleton, a
# temporary name is a frozen copy, a frozen singleton class refuses a def, a
# module's prepends come with it when it is included, a Module subclass
# reaches Module's surface with no receiver, and a string instance_eval runs
# with the class as self.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x').sub(/eval at [^)]*\)/, 'eval)')}"; end
  puts "#{n}: #{r}"
end
t(1) { Module.new.send(:append_features, 1) }
t(2) { Comparable.class_eval { |*a| a } }
t(3) { %w[foo= foo? @foo $foo 1x Foo _x].map { |n| begin; Module.new { attr_accessor n.to_sym }; :ok; rescue NameError => e; e.name; end } }
module Mxin; MIXIN = 1; end
class Usr; include Mxin; USER = 2; end
t(4) { [Object.const_defined?("Usr::MIXIN"), Object.const_defined?("Usr::MIXIN", false), Object.const_defined?("Usr::String")] }
t(5) { Object.const_defined?(:"Comparable::Usr") }
t(6) { Object.const_defined?("Usr::USER::X") }
module NM; end
t(7) { NM.module_eval "A = 1"; NM.module_eval "module A; end" }
t(8) { A8 = 1; [Object.const_defined?(:A8, false), NM.const_defined?(:A8, false)] }
t(9) { [catch(:t) { NM.module_eval "throw :t, 42"; 0 }, (NM.module_eval "raise ArgumentError" rescue $!.class)] }
t(10) { NM.module_eval("B9 = Class.new").class }
t(11) { [Module.new.public_class_method(:remove_const).class, (Object.remove_const rescue $!.class)] }
t(12) { m = Module.new; m.const_set(:N, Module.new); n = +"fake"; m::N.set_temporary_name(n); n.upcase!; [m::N.name, m::N.name.frozen?] }
t(13) { o = Object.new; c = class << o; self; end; c.freeze; class << o; def foo; end; end }
t(14) { m1 = Module.new; m2 = Module.new; m3 = Module.new; m2.prepend m1; m3.include m2; [m3.included_modules == [m1, m2], Class.new { include m2 } < m1] }
class MM < Module; def initialize; super; @al = ancestors.size; end; attr_reader :al; end
t(15) { MM.new.al }
class Usr2; end
t(16) { Usr2.instance_eval("def sm = :sm"); Usr2.module_eval("ME = 1"); Usr2.instance_eval("remove_const(:ME)"); [Usr2.instance_eval("self"), Usr2.sm, Usr2.constants] }
