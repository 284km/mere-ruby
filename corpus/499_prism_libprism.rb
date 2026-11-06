# Prism under mere-ruby: libprism compiled in and reached through five
# externs, with Prism's own Ruby library (shipped, as json's is) reading the
# parser's serialized answer -- the first of note 511's two Prism steps. And
# the two things beside it that stood in the way: `super` from a module
# prepended to String reaching the builtin unpack1 (Prism's polyfill), and
# the parameters of a builtin ruby writes in Ruby having names.
require "prism"
require "stringio"

p Prism::VERSION, Prism::BACKEND
r = Prism.parse("a = 1 + 2\nputs a\n")
p r.success?, r.errors.size, r.warnings.size, r.value.class
p r.value.statements.body.map(&:class)
p r.value.statements.body.first.name
puts r.value.statements.body.first.inspect
p r.source.lines.size, r.data_loc, r.magic_comments.size

p Prism.lex("a = 1\n").value.map { |t, _| t.type }
p Prism.dump("a = 1").bytesize
p Prism.parse_success?("a = 1"), Prism.parse_failure?("a =")
e = Prism.parse("a = ").errors.first
p e.message, e.type, e.level, e.location.start_offset, e.location.end_offset
p Prism.parse_comments("# hi\n1 # there\n").map(&:slice)
res = Prism.parse_lex("x = 1")
p res.value[0].class, res.value[1].size

p Prism::StringQuery.local?("foo"), Prism::StringQuery.local?("Foo")
p Prism::StringQuery.constant?("Foo"), Prism::StringQuery.constant?("foo")
p Prism::StringQuery.method_name?("foo?"), Prism::StringQuery.method_name?("1")

io = StringIO.new("1 + 2\n3 + 4\n__END__\n5 + 6")
r = Prism.parse_stream(io)
p r.success?, r.value.statements.body.length, io.read
io = StringIO.new("1 + 2\n3 + 4\n\"\n__END__\n\"\n5 + 6")
p Prism.parse_stream(io).value.statements.body.length
io = StringIO.new("x = <<~EOS\n  __END__\nEOS\n2")
p Prism.parse_stream(io).value.statements.body.length

node = Prism.parse("def foo(a, b = 1, *c, d:, &e) = 1", filepath: "x.rb", line: 10).value.statements.body.first
p node.class, node.name, node.location.start_line, node.parameters.requireds.size
p Prism.parse("foo", scopes: [[:foo]]).value.statements.body.first.class
p Prism.parse("foo").value.statements.body.first.class
p Prism.parse("x = 1", frozen_string_literal: true, version: "3.4").success?
p Prism.parse("\"a\"", frozen_string_literal: true).value.statements.body.first.frozen?
begin
  Prism.parse(1)
rescue TypeError => e
  p e.message
end
begin
  Prism.parse_file("/nonexistent/x.rb")
rescue SystemCallError => e
  p e.class
end
begin
  Prism.parse("x", version: "2.7")
rescue ArgumentError => e
  p e.message
end

# the polyfill's shape: a module prepended to String whose unpack1 calls super
String.prepend(Module.new {
  def unpack1(f, offset: 0)
    offset == 0 ? super(f) : self[offset..].unpack1(f)
  end
})
b = "\x01\x00\x00\x00\x02\x00\x00\x00".b
p b.unpack1("L"), b.unpack1("L", offset: 4), b.unpack("L2")
Array.prepend(Module.new { def pack(f) = super(f) })
p [65, 66].pack("C*")
p String.instance_method(:unpack1).parameters, String.instance_method(:unpack).parameters
p Array.instance_method(:pack).parameters, Array.instance_method(:first).parameters
p Array.instance_method(:sample).parameters, Dir.method(:glob).parameters
p String.instance_method(:sum).parameters, String.instance_method(:byteslice).parameters

# what test/prism's fixtures turned up in this interpreter's own parser:
# `<<~` counts a tab as reaching the next multiple of 8 columns, and an
# instance or class variable takes an implicit array on its right
x = <<~EOS
	 a
	b
EOS
p x
@a = 1, 2
@b = *[3], 4
class CV
  @@c = 5, 6
  def self.c = @@c
end
p @a, @b, CV.c
