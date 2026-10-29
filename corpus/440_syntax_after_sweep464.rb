# Syntax after sweep464: `\g<0>` calling the whole pattern, a heredoc whose
# identifier starts with a digit, a constant op-assign inside a method (only
# `C = v` there is a dynamic constant assignment), `and:` after a literal
# being `and` and a Symbol, and prism's errors for a bad `\u{...}`.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message.sub(/\A\(eval at [^)]*\):\d+: /, "")}"
end

# \g<0>: the whole pattern again, recursively
show("balanced") { "a(b,(c))d".scan(/(([^(,)]+|\((?:,|\g<0>)*\))+)/) }
show("nested parens") { ["((x))" =~ /\A\((\g<0>|x)\)\z/, $~ && $~.to_a] }
show("palindrome") { %w[abcba abca a].map { |s| s.match?(/\A(?:(.)\g<0>\1|.?)\z/) } }
show("left recursion") { Regexp.new("\\g<0>a") }
show("\\k<0>") { Regexp.new("a\\k<0>") }
show("\\k<-0>") { Regexp.new("a\\k<-0>") }

# a heredoc identifier may start with a digit, where a value starts
show("<<~0") { eval("<<~0 '1'\n \n0\#{}\n0") }
x = 3
show("shift still") { [x <<1, x <<~1] }
show("<<0 in an array") { eval("[<<0]\ny\n0") }

# op-assign to a constant inside a method compiles; plain `=` does not
module OpAsgn
  A = 1
  def self.bump
    OpAsgn::A += 1
  rescue NameError, TypeError => e
    e.class
  end
end
[
  "def m; A::B = 1; end", "def m; A::B += 1; end", "def m; A::B ||= 1; end",
  "def m; A::B &&= 1; end", "def m; B += 1; end", "def m; ::B ||= 1; end",
  "def m; ::B = 1; end",
].each do |src|
  show(src) do
    RubyVM::InstructionSequence.compile(src) && :ok
  rescue SyntaxError => e
    e.message[/dynamic constant assignment/]
  end
end
show("op-assign runs") { $VERBOSE = nil; r = OpAsgn.bump; $VERBOSE = false; [r, OpAsgn::A] }

# `and:` after a literal is `and` and a Symbol; as a hash key it is a label
y = 7and:sym
show("and:sym") { y }
show("[1]and:") { eval("z = [1]and:q; z") }
show("nil or:") { eval("z = nil or:q; z") }
show("keyword labels") { {and: 1, or: 2, if: 3} }
def kw(**k) = k
show("keyword args") { kw(1 => 2, unless: 4) }
show("trick") { eval("p_ = 0\n18*7and:`") }

# a bad \u{...}: prism's two errors at the character, three when the string
# never closes, and the list named from its backslash when the source ends
['"\u{xxxx}"', 'x = "ab\u{123.}"', 'x = "ab\u{zz', '"\u{1234"', '"\u{12', 'x = "\u{1F600'].each do |src|
  show(src) { eval(src) }
end
