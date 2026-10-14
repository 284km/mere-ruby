# Modules as CRuby's test_module asks them (note 336): a class copied by
# dup / clone reads its class variables in its own methods (they were the
# original's), a setter cannot be endless, a frozen class refuses
# deprecate_constant, and a bare module_function inside a method warns.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.sub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
class Gods314; @@rule = "Uranus"; def ruler0 = @@rule; def self.ruler1 = @@rule; end
Zeus314 = Gods314.clone
Hera314 = Gods314.dup
t(1) { Zeus314.class_variable_set(:@@rule, "Athena"); Hera314.class_variable_set(:@@rule, "Hera"); [Gods314.new.ruler0, Zeus314.new.ruler0, Hera314.new.ruler0, Gods314.ruler1, Zeus314.ruler1] }
def setter314(src)
  eval(src)
  :defined
rescue SyntaxError
  :syntax_error
end
t(2) { [setter314("def x314=(v) = v"), setter314("def []=(k, v) = v"), setter314("def ==(o) = true"), setter314("def <=(o) = true"), setter314("def x314=(v); v; end")] }
t(3) { c = Class.new { const_set(:A, 1) }.freeze; [(c.class_eval { private_constant :A } rescue $!.class), (c.class_eval { public_constant :A } rescue $!.class), (c.class_eval { deprecate_constant :A } rescue $!.class)] }
$stderr = $stdout
Module.new do
  def self.foo
    module_function
  end
  foo
end
t(4) { :warned_above }
