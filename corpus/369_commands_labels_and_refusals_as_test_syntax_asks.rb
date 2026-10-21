# A name at the head of a command, the constructs around it, and the
# refusals test_syntax asks for -- plus `<=>` between a number and an object

# `name:sym` is `name :sym` where a command can stand, a label elsewhere
def not_label(x = :none, **kw) = (kw.empty? ? [:sym, x] : [:kw, kw])
def r(*a) = a
p(if true then not_label:foo end)
p(begin not_label:foo end)
p(begin; ensure not_label:foo end)
p "#{not_label:foo}"
x = not_label:bar
p x
p [1].map { not_label:baz }
z = (true and not_label:qux)
p z
p r(not_label: 1), {not_label: 2}, r(1, not_label: 3)
p(true ? :t : :f)
v = 5
p(v > 1 ? v:0)
@nl = self
def @nl.cls = Class.new
class << not_label:foo; end
h = {
  a:1,
  b:"x"
}
p h

# blocks and groups
module Foo; def self.Bar(*a, &b) = [:bar, a, b&.call]; end
p(Foo::Bar { 1 })
p(false ? raise do end : tap do end)
p(while class Foo2; tap do end; end; break 7; end)
p (;),(),()
p (
),(1)
f = ->a=1...{ a }
p f.call, f.call(2)
o = Object.new
def o.[](*a) = a
p(o.[] 1, 2)
p 1.then {|
a
| a + 1 }
p [[1, 2]].map {|
a, b
;
c
| [a, b, c] }

# refusals, in ruby's words
def refused(src)
  RubyVM::InstructionSequence.compile(src)
  :ok
rescue SyntaxError => e
  e.message[/Invalid \w+( after \w+)?|void value expression|unexpected [^,;\n]*|identifier \S+ is not valid to set|&\. inside multiple assignment destination|numbered parameters are not allowed[^\n]*|'it' is not allowed[^\n]*/]
end
[
  '/#{break}/', '/#{next}/o', 'tap {a = (true ? next : break)}', 'class << (return); end',
  'proc {|arg1?:|}', '*a&.x=0', 'a&.x,=0', 'def foo(a:, **nil) end', 'def foo(**a, **nil) end',
  "begin; 1; rescue; retry; else; retry; end", '->{it+_2}', '->{_2+it}',
  'm :"#{m}" {}', 'm "#{x}" {}', 'm %[] {}', 'm [] {}', '0x0.0', '0.0.0', ': foo', 'foo(bar rescue nil)', '0..%q.',
  'tap {a = (true ? true : break)}', 'm(:"#{m}") {}', "begin; 1; rescue; retry; end",
].each { |s| p [s, refused(s)] }

# a number is not comparable with an object that does not coerce: no == is asked
class T
  include Comparable
  attr_reader :n
  def initialize(n) = @n = n
  def <=>(o) = @n <=> o.n
end
p [0 <=> T.new(0), 1.5 <=> T.new(0), (2**70) <=> T.new(0), Rational(1, 2) <=> T.new(0)]
p((0..10).cover?(T.new(0)..T.new(100)))
p(T.new(1) <=> T.new(2), T.new(3) == T.new(3))
