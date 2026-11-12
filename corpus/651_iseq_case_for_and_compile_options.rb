# Round 30 of note 548: RubyVM::InstructionSequence compiles Prism's tree
# to ruby's instructions -- a case with a dispatch hash and one without, a
# for loop's block with its hidden parameter, ||= on a local and on an
# instance variable, `new` inlined as opt_new, `class << self`, a top-level
# return -- and a compile option turns the optimisations off.
def show(src, opt = nil)
  iseq = RubyVM::InstructionSequence.compile(src, "<w>", "<w>", 1, opt)
  puts iseq.disasm
  p iseq.to_a.last
end

show(<<~RUBY)
  x = 2
  case x
  when 1 then :a
  when 2, 3.0 then :b
  else :c
  end
RUBY

show(<<~RUBY)
  y = 1
  case
  when y > 1 then :big
  when *[y] then :splat
  end
RUBY

show(<<~RUBY)
  a = []
  for i in [1, 2]
    a << i
  end
  a
RUBY

show(<<~RUBY)
  v = nil
  v ||= 1
  @w &&= v
  o = Object.new
  class << o
    def m(**nil) = 1
  end
  [*v, 2]
  return
RUBY

show("a['k'] = a['j']; 'z'.freeze; Object", false)
show("x = [1]\nx.size", specialized_instruction: false)
