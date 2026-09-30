# An append queues beside the string and the next read folds it in, so every
# way of reading a string has to see what was appended -- after enough appends
# that the queue is actually in use (a short string takes them straight in).
def grow(s, n, piece = "ab")
  n.times { s << piece }
  s
end

s = grow(+"start:", 200)
p s.size, s.bytesize, s[0, 8], s[-4..], s[400], s.index("ba", 300)
p s.count("a"), s.end_with?("ab"), s =~ /(ab){3}\z/, $~ && $~.pre_match.size

# aliases share the one mutable string
t = s
grow(s, 50, "xy")
p t.size, t.end_with?("xyxy"), t.equal?(s)

# dup / frozen copies / freeze / hash keys / symbols
d = grow(+"k", 64).dup
grow(d, 3, "!")
p d.size, d[-3..], d.frozen?
f = grow(+"f", 64).freeze
p f.frozen?, f.size
begin
  f << "x"
rescue => e
  p e.class
end
k = grow(+"key", 40)
h = { k => 1 }
grow(k, 1, "z")
p h.keys.first.size, h[k], k.size
p grow(+"sym", 30).to_sym.size

# appends mixed with reads and with in-place rewrites
m = +""
100.times { |i| m << i.to_s; m.upcase! if i == 50; m.slice!(0, 2) if i % 17 == 0 }
p m.size, m[0, 10], m.hash == m.dup.hash

# replace / clear / sub! in the middle of a run of appends
r = grow(+"r", 100)
r.replace("new")
grow(r, 10)
p r
r.clear
grow(r, 20, "-")
r.sub!("--", "=")
grow(r, 20, "+")
p r

# encodings: a BINARY buffer taking UTF-8 text, ASCII then not
b = String.new
grow(b, 100)
p b.encoding, b.size, b.ascii_only?
b << "é"
p b.encoding, b.bytesize, b.ascii_only?, b.valid_encoding?
u = grow(+"", 100)
u << "é"
p u.encoding, u.size, u.ascii_only?, u.valid_encoding?
grow(u, 10)
u << "\xff".b.force_encoding("UTF-8")
p u.valid_encoding?, u.size
u.force_encoding("ASCII-8BIT")
p u.size, u.encoding

# Integer codepoints, concat with several arguments, append_as_bytes
c = grow(+"c", 64)
c << 0x3042 << 33
c.concat("1", "2", c[0, 2])
c.append_as_bytes(65, "B")
p c.size, c[-9..], c.bytesize

# inspect, Marshal, pack/unpack, split, each_char, scan, format
w = grow(+"w", 64, "a\n")
p w.inspect.size, w.lines.size, w.split("\n").size
p Marshal.load(Marshal.dump(w)) == w, w.unpack1("a5"), w.scan(/a\n/).size
p format("%.4s|%d", w, w.size), w.each_char.count, w.sum

# StringIO writes at the end, then reads
require "stringio"
io = StringIO.new(+"")
200.times { |i| io.write("l#{i};") }
io.print("tail")
p io.string.size, io.string[-8..], io.pos
io.rewind
p io.read(6)
io.seek(0, IO::SEEK_END)
io << "!"
p io.string[-5..]

# the same string appended to by a method and read by a block
acc = +""
[1, 2, 3].each { |i| 40.times { acc << i.to_s } ; acc.size }
p acc.size, acc.squeeze, acc.reverse[0, 3], acc.tr("1", "x").count("x")
