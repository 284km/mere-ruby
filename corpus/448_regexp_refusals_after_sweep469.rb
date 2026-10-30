# Regexp refusals after sweep469: letters past the options a regexp knows
# are "unknown regexp option(s)", marked from the closing delimiter; and in
# a dynamic regexp, the pattern's own \u text beside an interpolated string
# literal that disagrees with it is a SyntaxError (ruby folds the two when
# it compiles), while the same text beside a value is a RegexpError.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message.sub(/\A\(eval at [^)]*\):\d+: /, "")}"
end

["/regexp/sQ", "/regexp/QZ", "/a/iQ", "%r{a}xQ"].each { |src| show(src) { eval(src) } }

[
  '/\u1234#{%q"\x80"}/', '/\u1234#{"\x80"}/', '/\u1234#{ }\x80/',
  '/#{"a"}/', '/a#{"a"}/', '/\u1234#{"a"}/',
].each do |r|
  show(r) { eval("# -*- encoding: US-ASCII -*-\n#{r}.encoding") }
end
v = "\x80".b
show("value beside \\u") { /\u1234#{v}/ }
