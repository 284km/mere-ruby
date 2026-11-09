# Round 3 of note 533 (the I/O family): IO::Buffer's value API, slices and
# copies; a program's own class methods of File ahead of the builtins; the
# standard streams' #to_i; the conversion refusals; Dir.glob's keywords;
# StringIO and a chilled string; realpath through an unsearchable directory.
require "stringio"
require "pathname"
require "tmpdir"
require "objspace"
Warning[:experimental] = false

# --- the standard streams answer #to_i, as #fileno
p [$stdin.to_i, $stdout.to_i, $stderr.to_i]

# --- conversion refusals in ruby's words
f = File.open(__FILE__)
[-> { f.lineno = "1" }, -> { f.lineno = nil }, -> { f.lineno = 2**32 }].each do |c|
  c.call
rescue => e
  p [e.class, e.message]
end
o = Object.new
def o.to_io = "io"
begin
  IO.try_convert(o)
rescue TypeError => e
  p e.message
end

# --- a class receiver's send with a block reaches its own class method
d = Dir.pwd
p Dir.send(:open, d) { |dir| dir.class }, Dir.public_send(:open, d) { |dir| dir.class }

# --- Dir.glob refuses a keyword it does not take (Pathname.glob hands them on)
[-> { Dir.glob("*", foo: 1) }, -> { Pathname.glob("*", foo: 1, bar: 2) }, -> { Dir["*", sort: true, flags: 0] }].each do |c|
  c.call
  p :ok
rescue ArgumentError => e
  p e.message
end

# --- StringIO.open with nothing is over an empty String
p StringIO.open.string

# --- IO::Buffer: values of every type, 128-bit ones included
b = IO::Buffer.new(64)
{ U8: 255, S8: -128, u16: 0x1234, U16: 0x1234, s32: -5, S32: -5, u64: 2**64 - 1, F64: 1.5, f32: 0.25,
  u128: 2**128 - 1, S128: -2**127, s128: 2**63 }.each do |t, v|
  b.set_value(t, 0, v)
  p [t, b.get_value(t, 0), IO::Buffer.size_of(t)]
end
p IO::Buffer.size_of([:u128, :U8]), IO::Buffer::NETWORK_ENDIAN
p b.set_values([:U8, :u16, :s32], 1, [1, 2, -3]), b.get_values([:U8, :u16, :s32], 1)
p b.values(:U8, 0, 4), b.each(:U8, 0, 2).to_a, b.each_byte(1, 3).to_a
b.set_value(:U8, 0, 300)
p b.get_value(:U8, 0)
[-> { b.get_value(:u16, 63) }, -> { b.set_value(:U8, -1, 0) }, -> { b.set_value(:X9, 0, 0) },
 -> { b.set_values([:U8], 0, [1, 2]) }, -> { b.set_value(:f64, 0, "a") }, -> { b.get_values(:U8, 0) },
 -> { IO::Buffer.for("x").set_value(:U8, 0, 1) }, -> { b.copy("s") }].each do |c|
  c.call
rescue => e
  p [e.class, e.message]
end
# ...copies, overlapping ones too, and a clear's byte
c = IO::Buffer.for("0123456789").dup
c.copy(c, 3, 7)
p c.get_string
c = IO::Buffer.for("0123456789").dup
c.copy(c, 0, 7, 3)
p c.get_string, c.copy(IO::Buffer.new(0), 0, 0)
z = IO::Buffer.new(4)
z.clear(260)
p z.get_string
[-> { z.clear("x") }, -> { z.clear(0, 20) }, -> { z.clear(0, 0, 20) }].each { |cl| begin; cl.call; rescue => e; p [e.class, e.message]; end }
# ...a dup is a writable buffer of its own, and the bitwise ones work on it
p IO::Buffer.for("1234").dup.readonly?, IO::Buffer.for("1234123412").dup.and!(IO::Buffer.for("133\x00")).get_string
# ...a slice is a SLICE, not EXTERNAL; resized it is a buffer of its own
s = IO::Buffer.new(4).slice
p s.external?, s.internal?, s.to_s.sub(/0x\h+/, "X"), s.resize(8).to_s.sub(/0x\h+/, "X")
m = IO::Buffer.new(4, IO::Buffer::MAPPED)
sl = m.slice(0, 2)
m.resize(8)
p sl.valid?
inner = IO::Buffer.new(IO::Buffer::PAGE_SIZE)
sl = inner.slice(0, 8)
inner.free
begin
  sl.resize(16)
rescue => e
  p e.class
end
# ...the hexdump's columns
p IO::Buffer.for("ABCDEFGHIJKLMNOPQ").hexdump
# ...get_string's refusals
g = IO::Buffer.new(8)
[-> { g.get_string(0, 9) }, -> { g.get_string(9) }, -> { g.get_string(-1) }, -> { g.get_string(0, -1) }].each do |gs|
  gs.call
rescue ArgumentError => e
  p e.message
end
# ...for, string and map refuse what is not theirs
[-> { IO::Buffer.for(Object.new) }, -> { IO::Buffer.string(-1) }, -> { IO::Buffer.map("nope") }].each do |cl|
  cl.call
rescue => e
  p e.class
end
# ...a transferred `for` buffer writes into the string until it is frozen
hello = %w"Hello World".join(" ")
buf = IO::Buffer.for(hello, &:transfer)
buf.set_string("Ciao!")
hello.freeze
begin
  buf.set_string("Hola")
rescue IO::Buffer::AccessError => e
  p [e.message, hello]
end

# --- a program's own class method of File comes before the builtin; a module
# prepended to File's singleton does too, and one included in it does not
m2 = Module.new { def basename(*) = :included; def file_extra = :extra }
File.singleton_class.include(m2)
p File.basename("/x"), File.file_extra
File.singleton_class.prepend(Module.new { def split(_a) = :prepended })
p File.split("/a/b")
class << File
  alias_method :__saved_dirname, :dirname
  def dirname(*) = :own
end
p File.dirname("/x"), File.join("a", "b")
class << File
  alias_method :dirname, :__saved_dirname
end
p File.dirname("/x/y")
begin
  Pathname("/").split
rescue TypeError => e
  p e.message
end

# --- realpath through a directory that cannot be searched is EACCES
Dir.mktmpdir do |dir|
  Dir.mkdir("#{dir}/f")
  Dir.mkdir("#{dir}/f/g")
  File.symlink("f/g", "#{dir}/h")
  File.chmod(0000, "#{dir}/f")
  if File.readable?("#{dir}/f")
    p :readable_anyway
  else
    p((File.realpath("#{dir}/h") rescue $!.class))
  end
  File.chmod(0755, "#{dir}/f")
end

# --- a chilled literal: ObjectSpace.dump says so, and StringIO#set_encoding
# leaves it alone (no warning) while a write warns once
said = []
Warning.singleton_class.prepend(Module.new { define_method(:warn) { |m, **| said << m[/literal string will be frozen/] } })
Warning[:deprecated] = true
$VERBOSE = false
p ObjectSpace.dump(eval(%{"test"})).include?('"chilled":true')
chilled = eval(%{""})
io = StringIO.new(chilled)
io.set_encoding(Encoding::BINARY)
p said.compact.size
io << "test"
p said.compact.size, io.string, io.string.equal?(chilled)
