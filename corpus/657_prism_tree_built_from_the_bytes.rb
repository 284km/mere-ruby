# Prism's node tree, built by the interpreter itself from the parser's
# serialized bytes instead of by running Prism's generated Ruby loader
# (m_prism_load.mere; the loader took 230 µs a node here). What has to hold
# is that the objects are the ones `new` would have made: each node's class,
# its instance variables in initialize's order, every kind of field -- a
# node, a list, a location, a constant, a
# frozen String in the program's encoding, an Integer of any size, a Float
# down to the sign of zero.
require "prism"

src = <<~'RUBY'
  def foo(a, b = 1, *c, k: 2, &blk)
    x = a + 12345678901234567890123 * -0.0
    puts "a#{x}b", :sym, /re/i, [1, 2r, 3i, 0xffffffffffffffff, -9223372036854775808, 4294967296]
  end
  foo(1) { |y| y.bar&.baz }
  class Foo::Bar < Baz; attr :é; end
RUBY
r = Prism.parse(src)
puts r.value.inspect
p r.errors, r.warnings.size, r.comments.size, r.source.offsets

d = r.value.statements.body[0]
p d.class, d.instance_variables
p d.location.class, d.location.start_offset, d.location.length, d.location.equal?(d.location)
p d.name, d.name_loc.slice, d.locals, d.parameters.keywords[0].name
call = r.value.statements.body[1]
p call.class, call.instance_variables, call.safe_navigation?, call.node_id.class, call.block.parameters.class
p call.arguments.arguments[0].value, call.message_loc.start_column, call.closing_loc.end_offset

# the literals: their values, and the strings' encodings and frozenness
puts_args = d.body.body[1].arguments.arguments
str = puts_args[0].parts[0]
p str.unescaped, str.unescaped.encoding, str.unescaped.frozen?, puts_args[1].unescaped
ints = puts_args[3].elements
p ints.map(&:class), ints[3].value, ints[4].value, ints[5].value, ints[3].value.class
flt = d.body.body[0].value.arguments.arguments[0].arguments.arguments[0]
p flt.value, 1 / flt.value, d.body.body[0].value.arguments.arguments[0].receiver.value

# a name that is not ASCII, and a program in another encoding
cls = r.value.statements.body[2]
sym = cls.body.body[0].arguments.arguments[0]
p cls.name, sym.unescaped, sym.unescaped.encoding, cls.constant_path.name
e = Prism.parse("# encoding: euc-jp\nx = \"\xA4\xA2\"\n\xA4\xA2 = 1\n".b)
p e.value.statements.body[0].value.unescaped.encoding, e.value.locals.map(&:encoding), e.value.locals.size

# the tree the generated loader makes (freeze: true still runs it) is the same
puts Prism.parse(src, freeze: true).value.inspect == r.value.inspect
p Prism.parse(src, freeze: true).value.statements.body[0].frozen?, d.frozen?

# the same reader for a file, the errors of a program that does not parse,
# and a tree that is walked
p Prism.parse_file(__FILE__).value.statements.body.size
bad = Prism.parse("def f(\n  1 +\n")
p bad.failure?, bad.errors.map(&:type).first(2), bad.value.class
count = 0
walk = ->(n) { count += 1; n.compact_child_nodes.each { |c| walk.(c) } }
walk.(r.value)
p count

# String#unpack of a negative zero keeps the sign (the loader's doubles do
# not come through unpack any more; this was found beside it)
p "\x00\x00\x00\x00\x00\x00\x00\x80".b.unpack1("E"), [-0.0].pack("D").unpack1("D"), [-0.0].pack("e").unpack1("e")
