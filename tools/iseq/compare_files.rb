# tools/iseq/compare_files.rb — the ISeq compiler against ruby, a whole FILE
# at a time (note 552).
#
# Run under the REFERENCE ruby. Each file is compiled by ruby itself and by
# lib/iseq_compiler_ext.rb, and the two results are compared: #to_a (every
# sequence, operand, line, node id, catch table) and #disasm. Where
# compare_with_ruby.rb asks about one construct per snippet, this asks about
# programs as they are written -- a `# coding:` line, a block argument after
# other arguments, a statement continued over lines. A file is one of
#
#   ok    the same Array and the same disassembly
#   FMT   the same Array, a different disassembly (the first line that differs)
#   DIFF  a different Array (the path to the first difference, both values;
#         a String operand's encoding counts)
#   SKIP  the compiler refused the file: NotImplementedError, and why
#   ERR   the compiler raised something else -- a defect
#   SYNTAX  ruby itself does not compile the file
#
# and the run exits non-zero when there is a FMT, a DIFF or an ERR.
#
#   ruby tools/iseq/compare_files.rb lib/iseq_compiler_ext.rb corpus/*.rb
require File.expand_path(ARGV.shift)
C = RubyVM::InstructionSequence::Compiler__
counts = Hash.new(0)
skips = Hash.new(0)
enc = ->(v) { v.is_a?(String) ? " (#{v.encoding})" : "" }
# the first place two Arrays differ: [path, mine, ruby]
walk = lambda do |x, y, path|
  if x.is_a?(Array) && y.is_a?(Array)
    (0...[x.size, y.size].max).each { |i| r = walk.(x[i], y[i], path + [i]) and return r }
    nil
  elsif x.is_a?(Hash) && y.is_a?(Hash)
    (x.keys | y.keys).each { |k| r = walk.(x[k], y[k], path + [k]) and return r }
    nil
  # (a String operand in its encoding too. Not a sequence's label, slot 5:
  #  ruby builds "block in m" and "<class:C>" as binary C strings, which no
  #  program is told apart by)
  elsif x != y || x.class != y.class || (x.is_a?(String) && path.last != 5 && x.encoding != y.encoding) then [path, x, y]
  end
end
ARGV.each do |f|
  src = File.read(f)
  name = File.basename(f)
  begin
    ref = RubyVM::InstructionSequence.compile(src, f, f, 1)
  rescue SyntaxError
    counts[:SYNTAX] += 1
    puts "SYNTAX #{name}"
    next
  end
  begin
    u = C.compile(src, f, f, 1, "<compiled>".encode(Encoding::US_ASCII), nil)
    a = C.to_a(u)
    d = C.disasm(u)
  rescue NotImplementedError => e
    counts[:SKIP] += 1
    skips[e.message.sub(/\ARubyVM::InstructionSequence: /, "")] += 1
    next
  rescue Exception => e
    counts[:ERR] += 1
    at = e.backtrace.grep(/iseq_compiler/).first(3).map { |l| l[/:(\d+):/, 1] }.join(", ")
    puts "ERR  #{name}: #{e.class}: #{e.message[0, 120]} (compiler lines #{at})"
    next
  end
  ra = ref.to_a
  rd = ref.disasm
  if (hit = walk.(a, ra, []))
    counts[:DIFF] += 1
    path, x, y = hit
    puts "DIFF #{name} at #{path.inspect[0, 70]}: mine=#{x.inspect[0, 70]}#{enc.(x)} ruby=#{y.inspect[0, 70]}#{enc.(y)}"
  elsif d != rd
    counts[:FMT] += 1
    ml = d.lines
    rl = rd.lines
    i = (0...[ml.size, rl.size].max).find { |k| ml[k] != rl[k] }
    puts "FMT  #{name}\n   mine: #{ml[i].to_s.rstrip[0, 150]}\n   ruby: #{rl[i].to_s.rstrip[0, 150]}"
  else
    counts[:ok] += 1
  end
end
unless skips.empty?
  puts "-- why a file was refused, most common first"
  skips.sort_by { |w, n| [-n, w] }.each { |w, n| puts format("%4d %s", n, w) }
end
puts "compare_files: #{ARGV.size} files -- #{counts[:ok]} the same, #{counts[:SKIP]} refused, " \
     "#{counts[:DIFF]} different, #{counts[:FMT]} disassembled differently, #{counts[:ERR]} failed" \
     "#{counts[:SYNTAX] > 0 ? ", #{counts[:SYNTAX]} not ruby" : ""}"
exit(counts[:DIFF] + counts[:FMT] + counts[:ERR] == 0 ? 0 : 1)
