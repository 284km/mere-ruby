# Syntax errors as prism words and marks them: the line of the source it
# names, the mark's place and width, and the reason. ISeq.compile's syntax
# check puts a line of its own in front of the source, which neither the
# frame nor the line number may show.

def check(src, *pats)
  RubyVM::InstructionSequence.compile(src, "t.rb", "t.rb", 1)
  puts "#{src.inspect}: compiled"
rescue SyntaxError => e
  m = e.message
  found = pats.map { |pt| pt.is_a?(Regexp) ? (m[pt] || "MISSING #{pt.source}") : (m.include?(pt) ? pt : "MISSING #{pt}") }
  puts "#{src.inspect}: #{found.join(' / ')}"
end

check("0000xyz", /\| +\^~~(?!~)/, "unexpected local variable or method")
check("1.2i1.1", /\|     \^~~(?!~)/, "unexpected float, expecting end-of-input")
check("1.2.3", "> 1 | 1.2.3", /\|    \^~(?!~)/, "unexpected fraction part after numeric literal",
      "unexpected integer; expecting a message to send to the receiver")
check("{hello\n  world}", "> 1 | {hello", "expected a `}` to close the hash literal")
v, $VERBOSE = $VERBOSE, nil
check("__END__\r<<<<<\n", "unexpected <<")
$VERBOSE = v
check("p { [it **2] }", "unexpected **; expected a `,` separator for the array elements")
check("def\nf(000)end", "t.rb:2:", "> 2 | f(000)end", /\|   \^~~(?!~)/, "unexpected integer; expected a `)` to close the parameters")
check("def\nf(&0)end", /\|    \^(?!~)/)
check("def\nf(x) = x")
check("'0123456789012345678901234567890123456789' abcdefghijklmnopqrstuvwxyz0123456789 123456789012345678901234567890123456789",
      "> 1 | ... abcdefghijklmnopqrstuvwxyz0123456789 12345678901234567890123456789 ...",
      /\|     \^~{35} /)
check("/\\u", "too short escape sequence")
check("/\\u{", "unterminated regexp meets end of file")
check("/\\u{\\n", "invalid Unicode list")
check("/\\u{41}/")
check("x = {a: 1,\n b: 2}")
