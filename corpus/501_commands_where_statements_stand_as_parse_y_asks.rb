# Where a paren-less call (a COMMAND) may stand, and where it may not: parse.y
# lets one be the statement, the whole value of an assignment, the sole
# argument of another call, and an operand of `and` / `or` / `not` / `!`;
# anywhere else -- an operand, an element, one argument among several, a
# default value, a `when` or `rescue` list -- it is "unexpected local variable
# or method". And the small refusals around it: parameter order, a splat after
# keywords, an argument after a block argument, a comma at the start of a line,
# `_1` as a target, `foo! += 1`, `case` without clauses, `for` without an
# index, `class A < B end`, `if 0 0`, `::foo`, `alias $a b`, `defined?()`.
def refused?(src)
  RubyVM::InstructionSequence.compile(src)
  false
rescue SyntaxError
  true
end

def foo(*a, **k, &b) = [a, k, b&.call]
def bar(*a) = a
def baz(x = nil) = x

# accepted (and what they mean)
x = foo bar 1, 2
p x
foo bar 3, 4
p(foo bar 5, 6)
p(foo(bar 3))
p [1].map { |v| foo v }
p(true ? (foo 1) : 2)
p "#{foo 4}"
z = foo 5 rescue p :no
p z
p((foo 1 if true))
p((foo 1 and foo 2))
p(not foo 0)
p((!foo 0))
p((1 in Integer))
p(((a = foo 2) in Array))
p [_1 ** 2] if false
p [1, 2].map { [_1 **2] }
p(foo *[1, 2], **{k: 1})
p(foo(*[1], &-> { :blk }))
def pq(a, b = 1, *c, d, e:, f: 2, **g, &h) = [a, b, c, d, e, f, g]
p pq(1, 2, 3, 4, e: 5)
def post(a = 1, b) = [a, b]
p post(9)
def fwd(a, ...) = foo(a, ...)
p fwd(1, 2, k: 3)
p(->(a, b = 1, *c; d) { [a, b, c, d] }.call(1))
p [1].each { |a,| p a }
p [[1, 2]].map { |a, (b, c)| [a, b, c] }
p(1.. && 2)
p((1..).first(2))
p defined? ()
p(defined?
  ())

# refused
[
  "a + b c", "{a: b c}", "a(b, c d)", "a b, c d", "1 if foo = bar baz",
  "1 and foo = bar baz", "a = b, c d", "a = *b c", "a && b c", "defined? a b",
  "foo 1 in a", "case; when a b; end", "[a b]", "begin; rescue a b; end",
  "...a b", "+a b", "a ? b c : d", "foo a: b c", "a(*b c)", "a(**b c)", "a(&b c)",
  "foo(bar 1 do end, 2)", "x = [foo 1 rescue 2]",
  "def foo(b:, a); end", "def foo(**rest, b:); end", "def foo(a, b = 1, c, d = 2, e); end",
  "def foo(a = 1, b, *c); end", "def foo(&block, a); end", "def foo(&, a); end",
  "def foo(..., a); end", "def foo(..., ...); end", "def f(**, ...); end",
  "def foo(a, b, c,); end", "-> (a, b, ) {}", "p { |&b,| }",
  "a(**kwargs, *args)", "a(foo: bar, *args)", "a(&block, foo)", "def f(*, **); p(**, *); end",
  "[a\n,]", "p(a\n,b)", "def f(a\n,b); end",
  "-> { _1, = 0 }", "a in _1", "_1, b = 0",
  "foo! += 1", "foo? ||= 1",
  "case :a\nend", "for in 1..10; end", "for a in b end", "class Foo < Bar end",
  "if 0 0; end", "unless 0 0; end", "while 0 0; end", "until 0 0; end",
  "::foo", "::foo::A", "A::$b", "alias $a b", "alias a $b", "foo(alias x y)", "foo(undef x)",
  "1.. || 2", "defined?()", "p(1..2..3)",
].each { |src| puts "#{src.inspect}: #{refused?(src) ? 'refused' : 'ACCEPTED'}" }
