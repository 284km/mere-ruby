# ISeq compiled with tailcall_optimization: a send the method leaves right
# after -- through nops and the jumps an `if` makes -- is a tail call
# (compile.c's VM_CALL_TAILCALL), and the VM makes it in the caller once the
# frame is left, so a method that calls itself last a million times does not
# grow the stack. Not in a rescue region, not in a block, not with a block;
# and a call made on another receiver, privately, or into a method that
# itself tail-calls, answers what it would have answered.
def tc(src)
  RubyVM::InstructionSequence.new("proc {|_|_.class_eval {#{src}}}", __FILE__, __FILE__, 1,
                                  tailcall_optimization: true, trace_instruction: false).eval
end

class TC676; end
tc(<<~END)[TC676]
  def down(n)
    return :ok if n < 1
    down(n - 1)
  end
  def count(c, f)
    if c < f
      count(c + 1, f)
    else
      [:counted, c]
    end
  end
  def even?(n) = n == 0 ? true : odd?(n - 1)
  def odd?(n) = n == 0 ? false : even?(n - 1)
  def via(o, n) = o.down(n)
  def hidden(n) = secret(n)
  private def secret(n) = n.zero? ? :secret : secret(n - 1)
  def guarded(n)
    begin
      n < 1 ? :guarded : guarded(n - 1)
    rescue
      :rescued
    end
  end
  def with_block(n) = n < 1 ? :blocked : [n].map { |x| with_block(x - 1) }.first
  def where = caller_locations(0, 1)[0].label
  def outer_where = where
END

o = TC676.new
p o.down(1_000_000)
p o.count(1, 300_000)
p [o.even?(100_001), o.odd?(100_001)]
p o.via(TC676.new, 50_000)
p o.hidden(50_000)
p o.guarded(500)
p o.with_block(200)
p o.outer_where
p (begin; o.secret(1); rescue NoMethodError => e; e.message[/private method '\w+'/]; end)
dis = RubyVM::InstructionSequence.compile("def f(n) = f(n - 1)", tailcall_optimization: true).disasm
p dis.include?("TAILCALL")
p RubyVM::InstructionSequence.compile("def f(n) = f(n - 1)").disasm.include?("TAILCALL")
