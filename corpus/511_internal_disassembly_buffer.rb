# The generated builtin disassembly must survive its startup buffer's lifetime
# and later collections. Compare complete entries, including their separators.
methods = ["".method(:unpack), [].method(:pack), 1.method(:times),
           [].method(:shuffle), [].method(:sample)]
methods.each do |method|
  GC.start
  puts method.name
  puts RubyVM::InstructionSequence.of(method).disasm
end
