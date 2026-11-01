# Unicode properties of a string in another encoding
s = "\xa4\xa2".force_encoding("euc-jp")
p s =~ Regexp.new('\p{Hiragana}'.force_encoding("euc-jp")), s =~ /\p{Hiragana}/e, "a".force_encoding("euc-jp") =~ /\p{AsciI}/e
r = eval('/\p{Hiragana}/'.force_encoding("euc-jp"))
p r.encoding, r.fixed_encoding?, r.options
r = eval('/\u{3042}\p{Hiragana}/'.force_encoding("euc-jp"))
p r.encoding, r.fixed_encoding?

# the right side of == / != is evaluated once
y = %w[a b c]
p(97.chr != y.shift, y)

# Integer#chr in encodings with no character model: ASCII, a single byte, or
# "invalid codepoint"
p 200.chr(Encoding::ISO_8859_1).bytes, (300.chr(Encoding::ISO_8859_1) rescue $!), (200.chr(Encoding::Big5) rescue $!), 65.chr(Encoding::Big5)
p((128.chr(Encoding.find("stateless-ISO-2022-JP-KDDI")) rescue $!), 65.chr(Encoding.find("stateless-ISO-2022-JP-KDDI")))

# JIS X 0212 in EUC-JP
k = [0x4E02].pack("U")
p k.encode("EUC-JP").bytes, "\x8F\xB0\xA1".force_encoding("EUC-JP").encode("UTF-8") == k, ("\x8F\xB0\xA1".force_encoding("CP51932").encode("UTF-8") rescue $!.class)

# CP51932's half-width bytes past the katakana go through to CP50220 as themselves
p "\x8E\xA1\x8E\xFE".force_encoding("cp51932").encode("cp50220").b, "\x8E\xA1\x8E\xFE".force_encoding("cp51932").encode("cp50221").b

# a path in another encoding names the file by its UTF-8 name
require "tmpdir"
Dir.mktmpdir do |d|
  f = File.join(d, [0x3042].pack("U"))
  File.write(f, "x")
  e = File.join(d, "\xA4\xA2".force_encoding("euc-jp"))
  p File.stat(e).size, File.exist?(f)
end
