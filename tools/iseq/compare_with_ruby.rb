# The ISeq compiler against ruby itself: run under the reference ruby, it
# compiles each snippet (separated by "----" lines) with both and compares
# to_a and disasm byte for byte.
#
#   ruby tools/iseq/compare_with_ruby.rb lib/iseq_compiler_ext.rb tools/iseq/snippets.txt

require_relative ARGV[0]
C = RubyVM::InstructionSequence::Compiler__
ok = 0; bad = 0
snippets = File.read(ARGV[1]).split("\n----\n")
snippets.each do |src|
  ref = RubyVM::InstructionSequence.compile(src)
  begin
    u = C.compile(src, "<compiled>", "<compiled>", 1)
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
