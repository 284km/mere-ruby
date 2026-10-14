# Class variables and eval as CRuby's test_variable / test_eval ask them
# (note 334): a class variable a parent defines after the child did is
# overtaken (RuntimeError), a frozen holder refuses a write, a class's
# singleton looks its class variables up in the class (not in the modules
# it was extended with), $$ is read-only, local_variables lists the
# innermost scope first, and eval refuses a bare break / next and a source
# in an ASCII-incompatible encoding.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.sub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
t(1) { eval "class Par312; end; class Ch312 < Par312; @@cv = 1; def self.cv = @@cv; end; class Par312; @@cv = 2; end; Ch312.cv" }
t(2) { eval "module M312; end; class C312; include M312; @@cv = 1; def self.cv = @@cv; end; module M312; @@cv = 2; end; C312.cv" }
t(3) { mod = Module.new; mod.class_variable_set(:@@foo, 1); mod.freeze; c = Class.new { include(mod) }; [(c.class_variable_set(:@@foo, 2) rescue $!.class), (c.class_eval("@@foo = 2") rescue $!.class), c.class_variable_get(:@@foo)] }
t(4) { c = Class.new; c.class_eval("def self.set(v) = @@a = v"); c.set(1); c.freeze; [(c.set(2) rescue $!.class), c.class_variable_get(:@@a)] }
module Oly312; @@rule = "Zeus"; end
t(5) { c = Class.new; c.extend(Oly312); r = [c.singleton_class.class_variables, (c.singleton_class.class_variable_get(:@@rule) rescue $!.class)]; c.class_variable_set(:@@foo, 1); r + [c.singleton_class.class_variables, c.singleton_class.class_variable_get(:@@foo)] }
t(6) { [(eval("$$ = 5") rescue $!.message), (eval("$* = []") rescue $!.message)] }
t(7) { bug = 1; [tap { |x| break local_variables }, proc { |y| 1.times { |z| break local_variables } }.call(0)] }
def se312(src)
  eval(src)
  :ran
rescue SyntaxError
  :syntax_error
end
t(8) { [se312("break if false"), se312("next"), se312("redo"), eval("[1].each { break 3 }"), eval("while true; break 4; end")] }
t(9) { eval("__ENCODING__".encode("utf-16le")) }
t(10) { [nil, true, false].map { |o| o.instance_eval { def ide312 = :ok }; o.ide312 } }
t(11) { (1.instance_eval { def ide312b = :ok } rescue $!.message) }
t(12) { [Math.module_eval(&:to_s), String.class_eval(&:name)] }
