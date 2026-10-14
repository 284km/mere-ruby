# super and the performance warning as CRuby's test_super / test_optimization
# ask them (note 335): super from an instance_eval of another object is
# ruby's TypeError (it searched the wrong object's chain), BasicObject's
# initialize may be aliased, and redefining a method ruby's VM optimizes --
# by its definition, so Array#- and String#% too -- warns under
# Warning[:performance].
def t(n); r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end; puts "#{n}: #{r.gsub(/0x\h+/,'0x')}"; end
class A335; def foo = [:a]; end
class B335 < A335; def foo = Object.new.instance_eval { super() }; end
t(1) { B335.new.foo }
module M335; def foo = Object.new.instance_eval { super() }; end
class C335 < A335; include M335; end
t(2) { C335.new.foo }
class D335 < A335; def foo = instance_eval { super() }; end
t(3) { D335.new.foo }
t(4) { class BasicObject; alias_method :initialize, :initialize; def initialize; @bug = 1; end; end; Object.new.instance_variable_get(:@bug) }
$stderr = $stdout
Warning[:performance] = true
class Array; undef -; def -(o) = []; end
class String; undef %; def %(o) = ""; end
class Hash; undef dup; def dup = {}; end
class Proc; undef []; def [](*) = nil; end
t(5) { :warned_above }
