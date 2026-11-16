# What a whole test file run on the ISeq VM answered otherwise than the
# evaluator (note 552 §10): test_module, test_proc, test_variable,
# test_refinement, test_syntax. A child runs one script as it is and with
# MERE_RUBY_VM=strict, and the two runs print the same lines, ruby's:
# `include m` in an instance_eval on a class is Module#include on the class
# (not on its singleton -- the evaluator did that too without parentheses),
# `private [:a, :b]` takes one Array of names, define_method as a statement
# answers the name, `proc { it }.parameters` has no name, an immediate's
# ivar write is a FrozenError, a constant or class variable written in a
# refine body is warned about, and -W0 says nothing of a top-level return's
# argument. (And on the evaluator too: a bare `private_methods` at the top
# level was a NameError.)
require "rbconfig"
require "tmpdir"

MAIN = <<~'RUBY'
  STDOUT.sync = true
  def t(l); r = yield; puts "#{l}: #{r.inspect}"; rescue Exception => e; puts "#{l}: #{e.class}: #{e.message}"; end
  M673 = Module.new
  t(1) { c = Class.new; r = c.instance_eval { include(M673) }; [r.equal?(c), c.include?(M673), c.singleton_class.include?(M673)] }
  t(2) { c = Class.new; c.instance_eval { include M673 }; [c.include?(M673), c.singleton_class.include?(M673)] }
  t(3) { c = Class.new; c.instance_eval { self.include(M673) }; c.include?(M673) }
  def foo673; :foo; end
  def bar673; :bar; end
  private [:foo673, :bar673]
  t(4) { private_methods.grep(/673/).sort }
  public [:foo673, :bar673]
  t(5) { private_methods.grep(/673/).sort }
  t(6) { k = Class.new { def a; end; def b; end; private [:a, :b] }; k.private_instance_methods(false).sort }
  t(7) { r = []; Class.new.class_eval { r << define_method(:x673) {}; r << define_method(:y673, instance_method(:x673)) }; r }
  t(8) { [proc { it }.parameters, lambda { it }.parameters, proc { it }.parameters(lambda: true), proc { _1 }.parameters, proc { [_1, _2] }.arity] }
  t(9) { 1.instance_eval { @a = 1 } }
  t(10) { :s673.instance_eval { @a = 1 } }
  t(11) { [nil.instance_variables, 1.0.instance_variables] }
  module R673
    refine String do
      W673 = 1
      @@w673 = 2
    end
  end
  t(12) { R673.const_get(:W673) }
RUBY

Dir.mktmpdir do |d|
  File.write(File.join(d, "main673.rb"), MAIN)
  runs = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, File.join(d, "main673.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  puts runs[0]
  puts "the same on the VM: #{runs[0] == runs[1]}"
  puts runs[1] unless runs[0] == runs[1]
  # (-W0: a top-level return's argument is ignored silently)
  File.write(File.join(d, "ret673.rb"), "puts :before\nreturn false; raise\n")
  w = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, "-W0", File.join(d, "ret673.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  p w
end
