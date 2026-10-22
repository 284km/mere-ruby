# The line a statement that goes on past its first line reports: the line it
# starts on (a `\` at the end of a line, a string across lines), and for a
# call, the line of the method name (`end.print` after a block, `.m` on a line
# of its own); and the line an eval's SyntaxError names

def line_of
  yield
  :none
rescue => e
  e.backtrace[0][/:(\d+):/, 1].to_i
end

base = __LINE__
p line_of { raise "a" \
  "b" } - base
p line_of {
  x = 1
  x.foo \
    (2)
} - base
p line_of {
  [1]
    .map { |v| v }
    .nosuch
} - base
p line_of {
  [1].
    map { |v| v }.
    nosuch
} - base
p line_of {
  z = [1,
    2].nosuch(3,
     4)
} - base
p line_of {
  w = %w(a b
    c).nosuch
} - base
p line_of {
  1.times do
    :x
  end.nosuch do
  end
} - base
p line_of {
  raise "x
y"
} - base

base = __LINE__
q = 1 \
  + __LINE__
p q - base
r = "a" \
  "b"; p __LINE__ - base
def callee_line = caller_locations(1, 1)[0].lineno
p(callee_line \
  ) - base rescue p $!
p((callee_line \
  ) - base)

a = [1]
p defined?(a
  .size)
p defined?(a
  .nosuch)

begin
  eval("begin\n  1\nelse\n  2\nend\n", nil, "f.rb", 10)
rescue SyntaxError => e
  p e.message.lines.first.chomp
  p e.message.include?("else without rescue is useless")
end
