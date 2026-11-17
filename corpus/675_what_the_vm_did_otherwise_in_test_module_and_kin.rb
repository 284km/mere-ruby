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
  M675 = Module.new
  t(1) { c = Class.new; r = c.instance_eval { include(M675) }; [r.equal?(c), c.include?(M675), c.singleton_class.include?(M675)] }
  t(2) { c = Class.new; c.instance_eval { include M675 }; [c.include?(M675), c.singleton_class.include?(M675)] }
  t(3) { c = Class.new; c.instance_eval { self.include(M675) }; c.include?(M675) }
  def foo675; :foo; end
  def bar675; :bar; end
  private [:foo675, :bar675]
  t(4) { private_methods.grep(/675/).sort }
  public [:foo675, :bar675]
  t(5) { private_methods.grep(/675/).sort }
  t(6) { k = Class.new { def a; end; def b; end; private [:a, :b] }; k.private_instance_methods(false).sort }
  t(7) { r = []; Class.new.class_eval { r << define_method(:x675) {}; r << define_method(:y675, instance_method(:x675)) }; r }
  t(8) { [proc { it }.parameters, lambda { it }.parameters, proc { it }.parameters(lambda: true), proc { _1 }.parameters, proc { [_1, _2] }.arity] }
  t(9) { 1.instance_eval { @a = 1 } }
  t(10) { :s675.instance_eval { @a = 1 } }
  t(11) { [nil.instance_variables, 1.0.instance_variables] }
  module R675
    refine String do
      W675 = 1
      @@w675 = 2
    end
  end
  t(12) { R675.const_get(:W675) }
  # the visibility methods answer what they answer -- the names, or self --
  # and one the receiver defines itself is called; an Array goes to the
  # method in a class, and an unrelated call with an Array is a call
  class V675
    def a; end
    def b; end
    R = [private([:a]), private(:a), private(:a, :b), public(:a), private]
    X = 1
    R2 = [private_constant(:X)]
    def self.private(*args) = :intercepted
    R3 = private([:a])
  end
  t(13) { [V675::R, V675::R2.size, V675::R3, V675.private_method_defined?(:a)] }
  def takes675(v) = 1
  t(14) { a = Array.new(1000, :same); (1..50).sum { takes675(a) } }
  # a name with a space is no builtin: no Method, no undef, respond_to? false
  t(15) { [nil.respond_to?(:"class clone"), Object.new.respond_to?(:"< <="), (Object.new.method(:"class clone") rescue :none)] }
  t(16) { c = Class.new { define_method(:"class clone") { :real } }; [c.new.send(:"class clone"), (Class.new.send(:undef_method, :"class clone") rescue :refused)] }
RUBY

Dir.mktmpdir do |d|
  File.write(File.join(d, "main675.rb"), MAIN)
  runs = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, File.join(d, "main675.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  puts runs[0]
  puts "the same on the VM: #{runs[0] == runs[1]}"
  puts runs[1] unless runs[0] == runs[1]
  # (a required file's __ENCODING__ is the parser's, whatever the program
  #  that requires it made of Encoding.find)
  File.write(File.join(d, "enc675.rb"), "p __ENCODING__\n")
  File.write(File.join(d, "main675e.rb"), "def Encoding.find(*) = :intercepted\nrequire_relative 'enc675'\n")
  e = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, File.join(d, "main675e.rb"), err: [:child, :out]], &:read)
  end
  p e
  # (-W0: a top-level return's argument is ignored silently)
  File.write(File.join(d, "ret675.rb"), "puts :before\nreturn false; raise\n")
  w = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, "-W0", File.join(d, "ret675.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  p w
end
