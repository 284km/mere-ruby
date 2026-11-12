# The ISeq compiler against ruby itself: run under the reference ruby, it
# compiles each snippet (separated by "----" lines) with both and compares
# to_a and disasm byte for byte. A snippet whose first line is
# `#opt: <literal>` is compiled with that compile option (false, true or a
# Hash), as ISeq.compile's fifth argument.
#
#   ruby tools/iseq/compare_with_ruby.rb lib/iseq_compiler_ext.rb tools/iseq/snippets.txt

require File.expand_path(ARGV[0])
C = RubyVM::InstructionSequence::Compiler__
ok = 0; bad = 0
snippets = File.read(ARGV[1]).split("\n----\n")
DEFAULTS = RubyVM::InstructionSequence.compile_option
snippets.each do |src|
  opt = src[/\A#opt: (.*)$/, 1]&.then { |o| eval(o) }
  ref = RubyVM::InstructionSequence.compile(src, "<compiled>", "<compiled>", 1, opt)
  full = case opt
         when true, false then DEFAULTS.to_h { |k, v| [k, k == :debug_level ? v : opt] }
         when Hash then DEFAULTS.merge(opt)
         end
  begin
    u = C.compile(src, "<compiled>", "<compiled>", 1, "<compiled>", full)
    mine_a = C.to_a(u); mine_d = C.disasm(u)
  rescue NotImplementedError => e
    puts "SKIP #{src.lines.first.strip}: #{e.message}"; next
  end
  ra = ref.to_a; rd = ref.disasm
  if mine_a == ra && mine_d == rd
    ok += 1
  else
    bad += 1
    puts "== DIFF: #{src.inspect}"
    if mine_d != rd
      File.write("/tmp/m.txt", mine_d); File.write("/tmp/r.txt", rd)
      puts `diff /tmp/m.txt /tmp/r.txt | head -20`
    end
    if mine_a != ra
      require "pp"
      File.write("/tmp/ma.txt", mine_a.pretty_inspect); File.write("/tmp/ra.txt", ra.pretty_inspect)
      puts `diff /tmp/ma.txt /tmp/ra.txt | head -20`
    end
  end
end
puts "ok=#{ok} bad=#{bad}"
