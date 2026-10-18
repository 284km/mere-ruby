# RubyVM::InstructionSequence as far as it can be had without a VM (note
# 370): compile / new checks the syntax without running anything (a
# SyntaxError at once), #eval runs the source at the top level as main in a
# scope of its own, compile_option is kept and merged, #path / #first_lineno /
# #inspect, a binary round trip, and .of a method written in ruby (nil for a
# builtin). Two things found on the way: a top-level method called ON main
# from inside another object's method runs with main as self, and a block
# written in another file (an eval'd proc) gives the caller its file back.
I = RubyVM::InstructionSequence
p I.compile("1 + 2").eval
x = 5
p I.compile("x = 10; x").eval, x
p(begin; I.compile("1 +"); rescue SyntaxError => e; e.class; end)
ran = []
I.compile("ran << :ran")
p ran
k = Class.new
I.new("proc {|_|_.class_eval { def a = :a }}", "f.rb", "f.rb", 3, tailcall_optimization: true).eval[k]
p k.new.a
i = I.compile("[__FILE__, __LINE__]", "a.rb", "a.rb", 7)
p i.path, i.first_lineno, i.inspect, i.eval
p I.load_from_binary(i.to_binary).eval
p I.compile_option[:tailcall_optimization]
I.compile_option = {tailcall_optimization: true}
p I.compile_option[:tailcall_optimization], I.compile_option[:peephole_optimization]
I.compile_option = false
p I.compile_option[:peephole_optimization]
def mm = 1
p I.of(method(:mm)).class, I.of(1.method(:+))
I.compile("def top_from_iseq = :t").eval
p top_from_iseq
class A
  def eval(*) = :wrong
  def run = TOPLEVEL_BINDING.receiver.__send__(:foo)
end
def foo = [self.to_s, eval("1")]
p A.new.run
pr = eval("proc { 1 }", nil, "elsewhere.rb", 3)
pr.call
def after_block = 1
p File.basename(method(:after_block).source_location[0]), File.basename(caller(0)[0][/\A[^:]+/])
