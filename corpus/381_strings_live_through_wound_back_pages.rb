# Strings are kept in pages of 4096 slots, and a page whose strings all died
# is wound back and reused: what a program still holds -- a string in a local,
# in an array, appended to, re-encoded, frozen, as a hash key, a symbol's name
# -- reads the same across any number of collections in between

keep = "kept"
olds = []
5.times { |i| olds << "old#{i}" }
20_000.times { |i| "garbage#{i}" * 2 }
GC.start
p keep, olds

buf = +"x"
10_000.times { |i| buf << "y"; "tmp#{i}" }
GC.start
p buf.size, buf[0, 3], buf[-2, 2]

bin = "\xff\xfe".b
utf = "héllo"
sj = "あ".encode("Shift_JIS")
30_000.times { |i| i.to_s }
GC.start
p bin.encoding, bin.bytes, utf.encoding, utf.size, sj.encoding, sj.bytesize

fr = "frozen text".freeze
h = {"key one" => 1, "key two" => 2}
20_000.times { "#{rand(10)}x" }
GC.start
p fr.frozen?, fr, h["key one"], h["key two"], h.keys

ids = olds.map(&:object_id)
50_000.times { |i| "a" + i.to_s }
GC.start
p olds.map(&:object_id) == ids, olds

sym = :"made_from_#{keep}"
20_000.times { |i| "s#{i}" }
GC.start
p sym, sym.to_s, sym.to_s.frozen?

later = []
3.times do |round|
  10_000.times { |i| "drop#{i}" }
  later << "round#{round}-#{"z" * round}"
  GC.start
end
p later

big = "line\n" * 2000
20_000.times { |i| "t#{i}" }
GC.start
p big.lines.size, big.bytesize, big.count("\n")

s1 = "shared"
s2 = s1
20_000.times { "u" * 3 }
GC.start
s2 << "!"
p s1, s1.equal?(s2)
