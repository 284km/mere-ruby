# coding: US-ASCII
# A literal in a condition, in a US-ASCII source: its string literals carry
# the source's encoding as a tag, and the condition still sees the literal
# under it -- ruby's warning, and a bare regexp matched against $_. The
# warning names the line an eval was given.

def warned
  o, $stderr = $stderr, StringIO.new
  yield
  $stderr.string
ensure
  $stderr = o
end
require "stringio"
$VERBOSE = false

src = <<-END
  "foo" ? 1 : 2
END
puts "heredoc source: #{warned { eval src, nil, "z.rb", 4 }.inspect}"
puts "q source: #{warned { eval %q("bar" ? 1 : 2), nil, "y.rb", 7 }.inspect}"
puts "unless: #{warned { eval %q(x = 1 unless "s"; x), nil, "u.rb", 2 }.inspect}"
puts "regexp: #{warned { eval %q($_ = "xay"; /a/ ? :hit : :miss), nil, "r.rb", 9 }.inspect}"
$_ = "xay"
r = nil
warned { r = eval(%q(/a/ ? :hit : :miss)) }
puts "regexp matches $_: #{r}"
$_ = "q"
warned { r = eval(%q(/a/ ? :hit : :miss)) }
puts "regexp misses: #{r}"
puts "after a semicolon: #{warned { eval %q(x = 1; y = "s" ? 1 : 2), nil, "s.rb", 3 }.inspect}"
puts "over two lines: #{warned { eval %Q(x = 1\ny = ("s" ?\n 1 : 2)), nil, "t.rb", 9 }.inspect}"
