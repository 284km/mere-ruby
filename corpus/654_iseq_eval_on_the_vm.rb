# Round 33 of note 548: ISeq#eval runs a top-level sequence on the VM when
# every instruction in it is one the VM has -- literals, locals, ivars,
# globals, constants, sends (keywords, splats, &.), the opt_* forms,
# interpolation, branches, loops, case/when, multiple assignment -- and
# on the evaluator otherwise. The answers are ruby's either way.
def ev(src) = RubyVM::InstructionSequence.compile(src).eval

p ev("1 + 2 * 3 - 4 / 2")
p ev("a = [3, 1, 2]; b = a.sort; [a.max, b, a.include?(2), [a.size, b.first].min]")
p ev("h = {a: 1, 'b' => 2}; h[:c] = 3; h.map { |k, v| [k, v] }.size + h.size")
p ev("x = 0\ni = 0\nwhile i < 10\n  x += i if i.odd?\n  i += 1\nend\nx")
p ev("s = 'ab'; t = \"\#{s}-\#{1 + 1}\"; [t, t.frozen?, t.size]")
p ev("case 7\nwhen 1, 2 then :low\nwhen 3..9 then :mid\nelse :high\nend")
p ev("a, (b, c), *d = 1, [2, 3], 4, 5; [a, b, c, d]")
p ev("@iv = 4; $gv = 5; Kv = 6; [@iv, $gv, Kv, defined?(Kv)]")
p ev("def kw(a, b: 2, **r) = [a, b, r]; kw(1, b: 3, c: 4)")
p ev("v = nil; v&.length; w = v || 'x'; w *= 2; w")
p ev("r = (1..4); [r.sum, (1...4).to_a, ('a'..'c').to_a.join]")
begin
  ev("1 / 0")
rescue ZeroDivisionError => e
  p e.message
end
begin
  ev("nope_xyz")
rescue NameError => e
  p e.class, e.name
end
