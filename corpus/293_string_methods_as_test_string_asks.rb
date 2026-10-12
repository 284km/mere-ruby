# String methods as CRuby's test_string asks them (note 313): the count is
# checked before frozen and before the fast paths, <=> inverts the SIGN of
# what the other side answers, << takes a codepoint in UTF-16/32 and four
# bytes in GB18030, a truncated character at the end is no grapheme cluster,
# a broken byte is a character boundary of its own, a non-ASCII hash knows its
# encoding, rindex attempts a \K pattern at each position, split notices the
# block changing the receiver, UTF-16 strips and translates in characters, a
# #to_s that is not a String is written as rb_any_to_s, the numeric readers
# refuse an ASCII-incompatible string, digit upto is US-ASCII, * refuses a
# bad count, undump keeps an unknown escape and reads \u{A B}, and a String
# subclass is made, converted and deduplicated as its own class.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { s = "foo"; s[1, 2, 3] = ""; s }
t(2) { "foo".slice! }
t(3) { "x".dup.chomp!("", "") }
t(4) { "x".freeze.replace }
t(5) { "x".freeze.chomp!(1, 2) }
o = Object.new; def o.<=>(x) = 2**100
t(6) { "foo" <=> o }
o2 = Object.new; def o2.<=>(x) = -7
t(7) { "foo" <=> o2 }
t(8) { s = "".force_encoding("UTF-16LE"); s << 0x0300 << 0x20 << 0x10400; s.bytes }
t(9) { s = "".force_encoding("UTF-32BE"); s << 0x3042; s.bytes }
t(10) { 0xD800.chr("UTF-16BE") }
t(11) { ("a".force_encoding("GB18030") << 0x81308130).bytes }
t(12) { [0x80, 0x8140, 0x8130813A, 0x100000000].map { |n| n.chr("GB18030").bytes rescue $!.message } }
t(13) { ["안녕".byteslice(0, 4), "a\xEBb", "a\xEB\x80", "\xEB\x80a", "a\xFF"].map(&:grapheme_clusters) }
t(14) { ["hello\xBE".start_with?("hello"), "\xE3\x81\x82".start_with?("\xE3"), "hello\xBE".delete_prefix("hello")] }
t(15) { h1, h2 = ["\x80", "\x81"].map { |c| c.b.hash ^ c.hash }; [h1 != h2, "".hash == "".encode("UTF-32BE").hash, "a".hash == "a".b.hash] }
t(16) { ["abcdbce".rindex(/b\Kc/), "abcdbce".byterindex(/b\Kc/), "abcdbce".rindex(/b\Kc/, 4)] }
t(17) { s = "a b c"; s.split(" ") { |x| s.replace("z") if x == "c" } }
t(18) { s = "a b c"; s.split(" ") { |x| s.replace("a b c") } }
t(19) { ["\x00 0b0 ".force_encoding("UTF-16BE").strip, " あ\t".encode("UTF-16LE").lstrip.encode("UTF-8")] }
t(20) { "あ ".encode("ISO-2022-JP").rstrip }
t(21) { str, range, star = %w[b a-z *].map { |s| s.encode("utf-16le") }; str.tr(range, star).encode("UTF-8") }
t(22) { x = Object.new; def x.to_s = self; "foobarbaz".sub("bar") { x }.sub(/0x\h+/, "0x") }
t(23) { s = +""; s.sub!(/\A/) { s.freeze; "zzz" } }
t(24) { ["12".encode("UTF-16LE").to_i, "12".force_encoding("ISO-2022-JP").hex] rescue $! }
t(25) { [["0".upto("2").map(&:encoding).uniq], ["9".upto("11").map(&:encoding).uniq], ["a1".upto("a2").map(&:encoding).uniq]] }
t(26) { "a" * -1 }
t(27) { "abc" * (2**62) }
t(28) { "" * (2**62) }
t(29) { ['"\\ca"'.undump, '"\\u{41 42  43}"'.undump, '"\\u{}"'.undump, '"\\u3042"'.encode("EUC-JP").undump.encoding] }
t(30) { '"\\u{110000}"'.undump }
class S2 < String; end
t(31) { S2.new(1) }
t(32) { [S2.new(encoding: "EUC-JP").encoding, S2.new("x").class, S2.try_convert("foo"), S2.try_convert(1)] }
t(33) { s = S2.new("foo"); d = -s; [d.class, d.frozen?, s.frozen?] }
t(34) { "".freeze.send(:initialize, capacity: 10) }
t(35) { "".freeze.send(:initialize) }
t(36) { [3.1, 3.999, -0.5].map { |f| "ab" * f } }
t(37) { [-3.14, Float::NAN, -Float::INFINITY, 1e30, 5e18].map { |f| begin; "a" * f; rescue Exception => e; "#{e.class}: #{e.message}"; end } }
