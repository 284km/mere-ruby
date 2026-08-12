# zlib is a C extension in CRuby; here it is the vendored mgz package plus a
# thin bridge. Decompression, CRC-32 and Adler-32 verify against CRuby;
# compression does not ship (see PAIN.md) and says so.
require "zlib"

p Zlib.crc32("abc")
p Zlib.crc32("")
p Zlib.crc32("hello world")
# the seed form: a running CRC, which is how a PNG chunk covers type + content
p Zlib.crc32("def", Zlib.crc32("abc"))
p Zlib.crc32("abcdef")
p Zlib.crc32("def", Zlib.crc32("abc")) == Zlib.crc32("abcdef")

p Zlib.adler32("abc")
p Zlib.adler32("")
p Zlib.adler32("hello world")

p Zlib::NO_COMPRESSION
p Zlib::BEST_SPEED
p Zlib::BEST_COMPRESSION
p Zlib::DEFAULT_COMPRESSION
