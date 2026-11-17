# Round 39 of note 552: what test_iseq and test_optimization still asked.
# RubyVM::InstructionSequence.of answers the sequence the file's own
# compilation has for a Method, a Proc or a backtrace's Location (its label,
# its parameters, the same object for the same code); compile refuses what
# ruby refuses at compile time; --dump=insns prints the main script's
# sequences; a shareable Proc's refusals; the operand after `or` takes its own
# one-line pattern match; a `===` the program gave true, false or nil is the
# one `when` calls; a unary operator is a call a TracePoint sees.
require "rbconfig"
ISeq = RubyVM::InstructionSequence
def t(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message.lines.map(&:chomp).join(" / ")}"
end

# -- ISeq.of ------------------------------------------------------------
def anon_star(*); end
def anon_keys(**); end
def anon_block(&); end
def takes_block; yield; end
def takes_none; end
t("anonymous parameters") { [:anon_star, :anon_keys, :anon_block].map { |m| a = ISeq.of(method(m)).to_a; a[a.index(:method) + 1] } }
t("use_block") { [ISeq.of(method(:takes_block)).to_a.dig(11, :use_block), ISeq.of(method(:takes_none)).to_a.dig(11, :use_block)] }
t("a method's") { i = ISeq.of(method(:takes_block)); [File.basename(i.path), i.label, i.base_label, i.first_lineno - __LINE__] }
def home_of_a_block
  ISeq.of(Proc.new {})
end
t("a block's") { i = home_of_a_block; [i.label, i.base_label, File.basename(i.absolute_path)] }
pr = proc {}
t("the same object") { [ISeq.of(pr).equal?(ISeq.of(pr)), ISeq.of(method(:t)).equal?(ISeq.of(method(:t)))] }
t("of a sequence") { c = ISeq.compile("p 1", __FILE__); [ISeq.of(c).equal?(c), ISeq.of(c).path == __FILE__] }
t("of a frame") { l = (raise "x" rescue $!.backtrace_locations[0]); i = ISeq.of(l); [i.class, i.path == __FILE__, ISeq.of(l).equal?(i)] }
t("a builtin in C") { ISeq.of(1.method(:+)) }

# -- what compile refuses -----------------------------------------------
t("allocate") { ISeq.allocate }
t("debug_level") { ISeq.compile("", debug_level: "") }
t("load_from_binary") { ISeq.load_from_binary(0) }
t("load is private") { defined?(RubyVM::InstructionSequence.load) }
t("yield outside a method") { ISeq.compile("using Module.new; yield", "f.rb", "f.rb", 10) }
t("break outside a loop") { ISeq.compile("x = 1\nfalse and break\ny = 2") }
t("a stray end") { ISeq.compile("end") }
t("a source in its encoding") { s = "あ = 1; あ".encode("Shift_JIS"); d = ISeq.compile(s).disasm; [d.encoding, d.valid_encoding?] }

# -- ruby --dump=insns ----------------------------------------------------
out = IO.popen([RbConfig.ruby, "--dump=insns", "-e", "until while 1; end; end"], err: [:child, :out], &:read).lines
t("--dump=insns") { [out.first.chomp, out.last.include?("leave"), out.size] }

# -- a shareable Proc's refusals ------------------------------------------
t("writes an outer local") { a = nil; Ractor.shareable_proc { a = nil } }
t("an unshareable outer") { b = []; Ractor.shareable_proc { b } }
t("a name that is not ASCII") { eval("あ = []; Ractor.shareable_proc { あ }") }
obj = Object.new
def obj.through(*) = Ractor.shareable_proc { super }
t("a bare super's parameters") { obj.through(*[]) }

# -- `or` / `and` and a one-line pattern match ------------------------------
# (in eval'd text: the compiler does not take pattern matching yet, and
#  ISeq.of above reads this file's own compilation)
t("or ... in") { eval("x = (true or 1 in 1); y = (false or 5 in Integer => n); [x, y, n]") }
t("and ... in") { eval("a = [1, 2] and a in [1, *rest]; rest") }
t("unreached pattern") { eval("if true or { a: 0 } in { a: } then [:then, a] else :else end") }

# -- case and a `===` of the program's own ---------------------------------
src = "class %s; undef ===; def ===(*) = false; end; p((case %s; when true then 1; when false then 2; when nil then 3; else :nomatch; end))"
t("=== redefined") { [["TrueClass", "true"], ["FalseClass", "false"], ["NilClass", "nil"]].map { |c, v| IO.popen([RbConfig.ruby, "-e", format(src, c, v)], &:read).chomp } }

# -- a unary operator is a call -------------------------------------------
seen = []
tp = TracePoint.new(:c_call) { |e| seen << e.method_id }
tp.enable { s = "a"; s = -s; n = 5; m = -n; lit = -"b" }
t("c_call of -@") { seen }
t("a negative Integer's own address") do
  IO.popen([RbConfig.ruby, "-e", 'class Integer; undef to_s; def to_s(*a) = a[0]; end; puts "#{-1} #{-2} #{3}"'], &:read).chomp
end
