# RubyVM::AbstractSyntaxTree answers parse.y's tree: the node types, the
# children in ast.c's order, the four numbers of where a node is, the extra
# locations, the script lines and tokens, the tree of a program that does not
# parse. Here the tree is made from Prism's (m_ast.mere replays parse.y's
# actions over it), so what has to hold is everything where the two parsers
# name things differently: a statement list's BLOCK chain, an argument list's
# LIST, a string's pieces, a heredoc's lines, `a ||= b`'s three forms, a
# pattern's shape, an empty body's BEGIN.
require "pp"
AST = RubyVM::AbstractSyntaxTree

def show(src, **kw)
  node = AST.parse(src, **kw)
  walk(node, 0)
end

def walk(node, depth)
  pos = "#{node.first_lineno}:#{node.first_column}-#{node.last_lineno}:#{node.last_column}"
  puts "#{"  " * depth}#{node.type} #{pos}"
  node.children.each do |c|
    if c.is_a?(AST::Node) then walk(c, depth + 1)
    else puts "#{"  " * (depth + 1)}#{c.inspect}"
    end
  end
end

show(<<~'RUBY')
  def foo(a, b = 1, *c, k: 2, **o, &blk)
    x = a + 12345678901234567890123 * -0.0
    puts "a#{x}b", :sym, /re#{x}/i, [1, 2r, 3i], %w[p q]
    return x if a
  ensure
    c.each { |y; z| y.bar&.baz ||= 1 }
  end
RUBY

show(<<~'RUBY')
  class Foo::Bar < Baz
    ;
    attr :e
    X ||= 1
    @a, (b, *$c), d.e = *f, 2
    def self.m(...) = super
  end
  module M; end
RUBY

show(<<~'RUBY')
  case [1, {a: 2}]
  in [Integer => n, {a: 1.. => m}] if n > 0 then m
  in String | nil
  else 0
  end
  x = <<~A + <<-B
    one #{1}
      two
  A
    three
    B
  for i, j in [[1, 2]] do redo end
  begin; 1; rescue E, *F => e; retry; else 2; end while y
  ->(a) { a } ; proc { _1 } ; proc { it } ; BEGIN { 0 } ; END { 0 }
  defined?(yield) and not __FILE__ or __LINE__
  alias $a $b ; undef c, :d
RUBY

# the same node, by the other things it answers
n = AST.parse("foo(1, *a, k: 2) do |x| end\n")
p n.type, n.children.size, n.children[2].type
call = n.children[2]
puts call.inspect
pp call
p call.source rescue p $!.class
p AST.parse("x = 1\n", keep_script_lines: true).script_lines
p AST.parse("x = 1 # c\n", keep_script_lines: true).children[2].source
p AST.parse("a.b(1)\n").children[2].locations.map { |l| l && [l.first_lineno, l.first_column, l.last_lineno, l.last_column] }
p AST.parse("x  = 1 # c\n", keep_tokens: true).all_tokens.map { |t| [t[1], t[2], t[3]] }
p AST.parse("1 + 2").children[2].node_id.class

# what it refuses, and what it answers nil for
begin
  AST.parse("def")
rescue SyntaxError => e
  p e.class
end
begin
  AST.parse(1)
rescue TypeError => e
  p e.class
end
begin
  AST::Node.new
rescue => e
  p e.class
end
p AST.of(Class.new { attr_reader :foo }.instance_method(:foo))

begin
  AST.parse("x = /[/")
rescue SyntaxError => e
  p e.class
end

# a program that does not parse still has a tree: a construct whose `end`
# never came, a statement with something after it, an `end` that closes a
# class by its indent, a condition that is not there
show("def foo\n  a = 1\n", error_tolerant: true)
show("m 1 do\n  a\n", error_tolerant: true)
show("x = 1 2\ny\n", error_tolerant: true)
show("module Z\n  class Foo\n    foo.\n  end\n\n  def bar\n  end\nend\nz\n", error_tolerant: true)
show("def m\n  if\nend\n", error_tolerant: true)

# the literals a tree holds are made by the parser: a program that redefines
# Regexp.new, Rational, Complex or Encoding.find (and parses inside it) does
# not reach them; its Strings and Regexps are frozen; an empty program has a
# source of its own
# literals are not built by redefinable methods, and a nested parse does not disturb the outer one
class Regexp
  class << self
    alias_method :orig_new_86, :new
    def new(*a)
      AST.parse("99")
      :intercepted
    end
  end
end
def Rational(*) = :intercepted
def Complex(*) = :intercepted
class Encoding; def self.find(*) = :intercepted; end
n = AST.parse("[/abc/i, 2r, 1.5r, 3i, 2ri, __ENCODING__, /x\#{1}y/]")
pp n
p n.children[2].children[0].children
p AST.parse("2r").children[2].children, AST.parse("3i").children[2].children, AST.parse("1.5r").children[2].children
p AST.parse("__ENCODING__").children[2].children
p AST.parse("/abc/").children[2].children[0], AST.parse("/abc/").children[2].children[0].frozen?
class Regexp
  class << self
    remove_method :new
    alias_method :new, :orig_new_86
  end
end
# the String and Regexp a node holds are frozen
s = AST.parse('"hi"').children[2].children[0]
p s, s.frozen?, (s.replace("changed") rescue $!.class)
d = AST.parse('"a#{1}b"').children[2].children
p d[0], d[0].frozen?
r = AST.parse('/abc/').children[2].children[0]
p r.frozen?, (r.instance_variable_set(:@x, 1) rescue $!.class)
# an empty program
e = AST.parse("", keep_script_lines: true)
p e.script_lines, e.source
p AST.parse("\n", keep_script_lines: true).source, AST.parse("x", keep_script_lines: true).source
