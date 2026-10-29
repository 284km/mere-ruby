# coding: US-ASCII
# Control and meta escapes as prism reads them: a blank argument is taken
# with a warning that spells the escape, a control character written as
# itself, a multibyte one, or a \u after them is refused from the backslash
# (from the `?` in a character literal); \M1 with no dash too; a codepoint of
# more than six digits; a ?\u literal is UTF-8 in a US-ASCII source; a byte
# that is no UTF-8 character inside a name is "invalid multibyte character".

require "stringio"

def run(src)
  o, $stderr = $stderr, StringIO.new
  v = eval(src.dup.force_encoding("UTF-8"))
  w = $stderr.string
  [v, w.sub(/\A.*?: warning: /, "").chomp]
rescue SyntaxError => e
  e.message.lines.drop(1).first(2).map { |l| l.sub(/\A.*?\| /, "| ") }.join.chomp
ensure
  $stderr = o
end
$VERBOSE = true

[
  '"\M1"', '"\C1"', '"\u{100000000}"', '"\C- "', '"\M- "', '"\M-\C- "', '"\C-\M- "',
  "\"\\C-\t\"", "\"\\M-\t\"", "\"\\M-\\C-\t\"", "\"\\C-\x01\"", "\"\\M-\\C-\x01\"",
  '"\c\u0000"', '"\c\U0000"', '"\C-\u0000"', '"\M-\U0000"', '"\C-\M-a"', '"\c?"',
  '?\C- ', '?\M-\C- ', "?\\C-\t", "?\\C-\x01", '?\c\u0000',
].each { |s| puts "#{s.inspect}: #{run(s).inspect}" }

puts "?\\u{1234}: #{eval('?\u{1234}').encoding}"
puts "?\\u1234: #{eval('?\u1234').encoding}"
puts "?a: #{eval('?a').encoding}"
puts "\" ?a\\x8a\": #{run(" ?a\x8a").inspect}"
puts "\"x = a\\x8a\": #{run("x = a\x8a").inspect}"
