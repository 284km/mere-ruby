# Long quoted source used to copy every accumulated prefix while lexing.
# Keep the evaluated strings alive across later parses and collections, too.
def check_literal(label, source, expected)
  value = eval(source)
  raise label unless value == expected && value.encoding == expected.encoding
  value
end

text = "ab" * 100_000
saved = []
saved << check_literal("double", '"' + text + '"', text)
saved << check_literal("single", "'" + text + "'", text)
saved << check_literal("escaped", '"' + '\n\x41\101\u0042' * 10_000 + '"', "\nAAB" * 10_000)
saved << check_literal("raw escapes", "'" + '\n\x41' * 10_000 + "'", '\n\x41' * 10_000)

$lex_events = []
source = '"' + text + '#{$lex_events << 1; "left#{2}"}#{$lex_events << 3; "right"}' + text + '"'
saved << check_literal("interpolation", source, text + "left2right" + text)
p $lex_events

$lex_global = "global"
@lex_ivar = "instance"
saved << check_literal("variables", '"before:#$lex_global/#@lex_ivar:after"', "before:global/instance:after")
saved << check_literal("empty", '"#{""}#{""}"', "")
quoted_source = <<'SOURCE'
"\"\\\#{literal}"
SOURCE
saved << check_literal("quoted punctuation", quoted_source, '"\#{literal}')
single_source = <<'SOURCE'
'\'\\\n'
SOURCE
saved << check_literal("single punctuation", single_source, "'\\\\n")
saved << check_literal("unicode", '"\u{41 3042 1F600}\0\cA"', "Aあ😀\0\x01")

# Backticks share the double-quoted scanner; intercept execution to inspect
# the command bytes without invoking a shell.
def `(command)
  command
end
saved << check_literal("command", '`' + text + '#{1}\n`', text + "1\n")

saved << check_literal("long Unicode escape", '"\u{' + '41 ' * 100_000 + '}"', 'A' * 100_000)
p eval(':"' + text + '"') == text.to_sym
p eval(":'" + text + "'") == text.to_sym

GC.start
20.times { eval('"later#{"nested"}literal"') }
GC.start
p saved.map(&:bytesize)
p saved[0] == text && saved[1] == text && saved[4] == text + "left2right" + text

['"unterminated', "'unterminated", '"\x"', '"\u12"', '"\u{110000}"'].each do |bad|
  begin
    eval(bad)
  rescue SyntaxError
    puts "syntax error"
  end
end
