# Three more shipped libraries, the randomness under them, and the fact that
# an interpreter-internal failure now says what it was.

require "stringio"
require "strscan"
require "securerandom"

io = StringIO.new("a\nbb\nccc\n")
p io.gets, io.gets, io.pos, io.eof?
p io.read, io.eof?
io.rewind
p io.readlines
io.rewind
lines = []
io.each_line { |l| lines << l }
p lines
w = StringIO.new
w.puts "x"
w.print "y", "z"
w << "!"
w.write("Q")
p w.string, w.size
sio = StringIO.new("hello")
p sio.read(2), sio.read(2), sio.read(2), sio.read(2)
sio.rewind
p sio.getc, sio.pos
p StringIO.open("ab") { |s| s.read }

s = StringScanner.new("hello world 42")
p s.scan(/\w+/), s.pos, s.eos?
p s.scan(/\w+/), s.scan(/\s+/), s.scan(/\w+/)
p s.rest
p s.scan(/\s+/), s.scan(/\d+/), s.eos?
t = StringScanner.new("abc")
p t.check(/a/), t.pos, t.match?(/ab/), t.pos
p t.skip(/ab/), t.pos, t.getch, t.eos?
u = StringScanner.new("key: value")
p u.scan_until(/:/), u.pos, u.rest
u.reset
p u.pos, u.peek(3)

p SecureRandom.hex(4).length, SecureRandom.hex.length
p((SecureRandom.hex(4) =~ /\A[0-9a-f]{8}\z/) ? true : false)
p SecureRandom.uuid.length
p((SecureRandom.uuid =~ /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/) ? true : false)
p SecureRandom.alphanumeric(10).length

# Kernel#rand
p rand.class, rand().class
r = rand(10)
p r.class, (r >= 0 && r < 10)
p rand(0).class
v = rand(1..6)
p v.class, (v >= 1 && v <= 6)
p srand.class, Random.rand(5).class, Random.new.rand(5).class
p((0...20).map { rand(3) }.uniq.size > 1)

# a builtin must not shadow an object's own method of the same name
class Reader
  def initialize(lines); @lines = lines; @i = 0; end
  def gets; l = @lines[@i]; @i += 1; l; end
  def readlines; out = []; while (l = gets); out << l; end; out; end
end
p Reader.new(["a", "b"]).readlines

# `::Kernel::raise ::ArgumentError, "..."`, and the same wrapped over lines
begin
  ::Kernel::raise ::ArgumentError, "boom"
rescue => e
  p [e.class.to_s, e.message]
end
begin
  ::Kernel::raise ::ArgumentError,
    "wrapped"
rescue => e
  p [e.class.to_s, e.message]
end
begin
  Kernel.raise ArgumentError, "x"
rescue => e
  p e.class
end
p ::Kernel
p Math::sqrt(4.0)
# `a::B` is still scope resolution on `a`, never `a(::B)`
def lower_a; nil; end
p defined?(lower_a::B)

# an internal failure carries its message instead of a bare "error"
begin
  1.count
rescue Exception => e
  # (the message wording differs from CRuby's, which names the receiver too)
  p [e.class.to_s, e.message.include?("count")]
end
begin
  raise ArgumentError, "a real one"
rescue Exception => e
  p [e.class.to_s, e.message]
end
