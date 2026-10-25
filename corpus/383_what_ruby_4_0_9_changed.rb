# The reference ruby moved from 4.0.6 to 4.0.9 (2026-10-25). What the move
# changed that a program can see, and the gaps the new tests found next to it

# Set: compare_by_identity is kept by what an operation makes, a set changed
# while it is walked refuses, and & walks the smaller side
iset = Set.new.compare_by_identity
x1 = +"x"; x2 = +"x"
r = iset ^ [x1, x2]
p r.size, r.compare_by_identity?, x1.frozen?
p (iset & [1, 2]).compare_by_identity?
c = Set["a", "b"].compare_by_identity; c.collect! { |x| x }; p c.compare_by_identity?
f = Set[Set[1, 2]].compare_by_identity; p f.flatten.compare_by_identity?; f.flatten!; p f.compare_by_identity?
p Set["a", "b"].compare_by_identity.classify { |x| x }.values.map(&:compare_by_identity?)
p Set["a", "b"].compare_by_identity.divide { |x, y| x == y }.map(&:compare_by_identity?)
[:add, :merge, :cbi, :reset].each do |k|
  s = Set[1, 2]
  begin
    s.each { k == :add ? s.add(3) : k == :merge ? s.merge([3]) : k == :cbi ? s.compare_by_identity : s.reset }
    p [k, :none]
  rescue RuntimeError => e
    p [k, e.message]
  end
end
p Set[3, 1, 2] & [2, 3], Set[3, 1, 2] & Set[2, 3], Set[2, 3] & Set[3, 1, 2]

# the block an Enumerable method hands to a custom #each answers nil, even
# called after the method returned
%i[min max min_by max_by sum].each do |m|
  enum = Object.new
  class << enum
    include Enumerable
    attr_reader :block
    def each(&block) = (@block = block)
  end
  seen = []
  case m
  when :sum then enum.sum { |x| seen << x; x }
  when :min_by, :max_by then enum.send(m, 2) { |x| seen << x; x }
  else enum.send(m, 2)
  end
  p [m, enum.block.call(1), seen]
end

# a pattern that needs more than 32767 range repeats or null checks
[["(?:foobar){0,100}", 32767], ["(?:foobar){0,100}", 32768], ["(?:(?:a)?|(?:b)?)*", 32768]].each do |src, n|
  begin
    Regexp.new(src * n)
    p [n, :ok]
  rescue RegexpError => e
    p [n, e.message[0, 40]]
  end
end
begin
  eval("/#{"(?:foobar){0,100}" * 32768}/")
rescue SyntaxError => e
  p e.message.sub(/\A.*?:\d+: /, "")[0, 40]
end
p(/a\/b#{"\x01"}/.inspect)

# curry's arity through #to_int, asked once
p proc { |x, *y| x }.curry(1r)[42]
called = 0
arity = Object.new
arity.define_singleton_method(:to_int) { called += 1; 2 }
p proc { |x, y| x + y }.curry(arity)[1][2], called

# _id2ref names an id it does not know as a number, and finds a String
begin
  ObjectSpace._id2ref(2**80)
rescue RangeError => e
  p e.message
end
str = String.new("kept")
p ObjectSpace._id2ref(str.object_id).equal?(str)

# a block or fallback that changes the string being read refuses
s = "ABCD"
begin
  s.unpack("C*") { s << "E" }
rescue RuntimeError => e
  p e.message
end
s = "あ" * 10
begin
  s.encode("US-ASCII", fallback: proc { s.clear; "?" })
rescue RuntimeError => e
  p e.message
end

# a symbolic link that leads only to itself
require "tmpdir"
Dir.mktmpdir do |d|
  path = File.join(d, "loop")
  File.symlink("loop", path)
  begin
    File.stat(path)
  rescue SystemCallError => e
    p e.class
  end
end

# lazy flat_map walks an element with #each and #force by its #each
enum = Object.new
class << enum
  include Enumerable
  attr_reader :block
  def force = true
  def each(&block) = (@block = block)
end
yielded = []
[enum].lazy.flat_map { |x| yielded << x; x }.each { |x| }
p enum.block.call(42), yielded.size
p [1, [2, 3]].lazy.flat_map { |x| x }.to_a

# a separator matches where a character begins, and a limit ends on one
str = "\xa2\xa4\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa".force_encoding("euc-jp")
rs = "\xa4\xa4".force_encoding("euc-jp")
[nil, 3].each do |lim|
  r, w = IO.pipe
  r.set_encoding("euc-jp")
  w.write(str); w.close
  p (lim ? r.gets(rs, lim) : r.gets(rs)).bytes
  r.close
end

# %Z's abbreviation keeps its encoding, or takes the format's; and a Time
# subclass formats
class Zone
  def initialize(abbr) = @abbr = abbr
  def local_to_utc(t) = t
  def utc_to_local(t) = t
  def abbr(t) = @abbr
end
class MyTime < Time; end
z = Zone.new("éAAA")
out = MyTime.new(2020, 1, 1, 0, 0, 0, z).strftime("A%Z".encode(Encoding::ISO_8859_1))
p out.encoding, out.valid_encoding?
out = MyTime.new(2020, 1, 1, 0, 0, 0, z).strftime("\u0080%Z".encode(Encoding::ISO_8859_1))
p out.encoding, out.valid_encoding?
p MyTime.new(2020, 1, 2).strftime("%Y-%m-%d")

# interning an invalid String raises through a redefined
# EncodingError#initialize
class EncodingError
  def initialize(...)
    $encoding_error_initialized = true
    super
  end
end
begin
  :"#{(+"\xFF").force_encoding(Encoding::UTF_8)}"
rescue EncodingError => e
  p e.class, $encoding_error_initialized
end
