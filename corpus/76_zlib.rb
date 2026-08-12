# zlib is a C extension in CRuby; here it is the vendored mgz package plus a
# thin bridge, and it compresses for real.
require "zlib"

p Zlib.crc32("abc")
p Zlib.crc32("")
p Zlib.crc32("hello world")
# the seed form: a running CRC, which is how a PNG chunk covers type + content
p Zlib.crc32("def", Zlib.crc32("abc"))
p Zlib.crc32("def", Zlib.crc32("abc")) == Zlib.crc32("abcdef")

p Zlib.adler32("abc")
p Zlib.adler32("")
p Zlib.adler32("hello world")

p Zlib::NO_COMPRESSION
p Zlib::BEST_SPEED
p Zlib::BEST_COMPRESSION
p Zlib::DEFAULT_COMPRESSION

# round trips, including bytes that a NUL-terminated concatenation would eat
[
  "",
  "a",
  "hello hello hello hello world world world",
  "AB\x00CD\x00\x00EF",
  "\x00" * 40,
  ("mere " * 200),
  (0..255).to_a.pack("C*"),
].each do |s|
  d = Zlib::Deflate.deflate(s)
  p [s.bytesize, Zlib::Inflate.inflate(d) == s]
end

# a stream written by the real zlib decompresses here
p Zlib::Inflate.inflate(File.binread("/tmp/z_ruby.bin"))

# ...and the compressor actually compresses
big = "abcdefgh" * 400
p Zlib::Deflate.deflate(big).bytesize < big.bytesize
