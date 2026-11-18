# tools/iseq/compare_coverage.rb — the ISeq compiler's branch coverage
# against ruby's (note 552).
#
# Run under the REFERENCE ruby. While Coverage counts branches, ruby compiles
# them into a sequence: a `nop` with a coverage event where each branch
# starts, and the file's structure -- which constructs branch, and where each
# branch is -- that Coverage.result answers. Each snippet (separated by
# "\n----\n") is compiled by ruby that way and by lib/iseq_compiler_ext.rb
# with its :coverage_branches option, and compared: the disassembly, and the
# structure as Coverage.peek_result shows it.
#
#   ruby tools/iseq/compare_coverage.rb lib/iseq_compiler_ext.rb tools/iseq/coverage_snippets.txt
require "coverage"
require File.expand_path(ARGV[0])
C = RubyVM::InstructionSequence::Compiler__
Coverage.setup(branches: true)
ok = bad = 0
File.read(ARGV[1]).split("\n----\n").each_with_index do |src, i|
  path = "cov_snippet_#{i}.rb"
  ref = RubyVM::InstructionSequence.compile(src, path, path)
  rd = ref.disasm
  rs = Coverage.peek_result[path][:branches].to_h { |k, v| [k, v.keys] }
  u = C.compile(src, path, path, 1, "<compiled>".encode(Encoding::US_ASCII), C::DEFAULT_OPTIONS.merge(coverage_branches: true))
  md = C.disasm(u)
  # the structure as Coverage numbers it: a base, then its branches
  id = -1
  ms = C.branch_structure(u).to_h do |b|
    [[b[0], id += 1, *b[1, 4]], b[5].map { |br| [br[0], id += 1, *br[1, 4]] }]
  end
  if md == rd && ms == rs
    ok += 1
  else
    bad += 1
    puts "== DIFF: #{src.inspect[0, 100]}"
    if md != rd
      ml = md.lines
      rl = rd.lines
      k = (0...[ml.size, rl.size].max).find { |j| ml[j] != rl[j] }
      puts "  mine: #{ml[k].to_s.rstrip}\n  ruby: #{rl[k].to_s.rstrip}"
    end
    puts "  mine: #{ms.inspect}\n  ruby: #{rs.inspect}" if ms != rs
  end
end
puts "ok=#{ok} bad=#{bad}"
exit(bad == 0 ? 0 : 1)
