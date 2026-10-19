# Parse errors as test_parse asks (note 384): a syntax check (the program
# behind a BEGIN that leaves before anything runs) refuses what ruby's parser
# refuses, in ruby's words -- writes to match variables, constants assigned in
# a method, a class in a method, a lowercase class name, a value that never
# comes back on the right of `=`, a block given twice, a block parameter
# named twice or not a local -- and the lexer names what it cannot read; and
# a few forms parse: `::A, ::B = 1, 2`, `recv::(args)`, `c::foo, c::bar = 1,
# 2`, a label whose value is on the next line, `\u{0}`, `(/(?<a>.)/) =~ s`.
def check(code, words)
  catch(:ok) { eval("BEGIN { throw :ok }\n" + code) }
  :accepted
rescue SyntaxError => e
  e.message.include?(words) ? :refused_in_those_words : e.message
end
[
  ["$& = 1", "Can't set variable $&"], ["$1, $2 = 1, 2", "Can't set variable"], ["$1 &= 1", "Can't set variable $1"],
  ["alias $foo $1", "can't make alias for the number variables"],
  ["def foo\n  ::FOO = 1\nend", "dynamic constant assignment"], ["def foo\n  self::A, self::B = 1, 2\nend", "dynamic constant assignment"],
  ["def foo\n  class Foo; end\nend", "class definition in method body"], ["class foo; end", "class/module name must be CONSTANT"],
  ["x = return 1", "void value expression"], ["x, y = return", "void value expression"], ["x = begin return ensure end", "void value expression"],
  ["x = begin return; rescue; end", ""], ["x = begin return; rescue; return; else end", ""],
  ["foo(&proc {}) {}", "both block arg and actual block given"], ["1.times { |a, a| }", "duplicated argument name"],
  ["o.foo { |; @a| }", "formal argument cannot be an instance variable"],
  ["%s", "unterminated quoted string"], ["%z()", "unknown type of %string"], ["%w[abc", "unterminated list"],
  ["/x", "unterminated regexp meets end of file"], ["?", "incomplete"], ["\\foo", "unexpected backslash"],
  ["x = \\ 42", "unexpected escaped space"], ["\x01", "Invalid char '\\x01' in expression"],
  ["proc { a = $% }", "'$%' is not allowed as a global variable name"], [":@@", "'@@' without identifiers is not allowed"],
  [":$01234", "'$01234' is not allowed as a global variable name"], ["$0 = 'prog'", ""], ["class << self; end", ""],
].each { |c, w| p [c, check(c, w)] }
::TOP_A, ::TOP_B = 1, 2
p [TOP_A, TOP_B]
module M360; A, @b = 3, 4; end
p M360::A
c = Class.new { class << self; attr_accessor :foo, :bar; end }
c::foo, c::bar = 5, 6
p [c.foo, c.bar]
p proc { |x| x * 2 }::(21)
def set(h) = h
v = set foo:
  1
p v
w = set "bar":
  2
p w
p "a\u{0}b".bytes, :"x\u{}y"
(/(?<cap>.)/) =~ "z"
p defined?(cap)
/(?<cap2>.)/ =~ "z"
p cap2
p(begin; 1; rescue; else; end)
