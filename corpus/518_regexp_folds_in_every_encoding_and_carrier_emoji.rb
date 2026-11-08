# encoding: iso8859-7
# What test/ruby/enc found (note 511's stage 3): the regexp engine folds
# case and reads properties in UTF-8 only, so a search in a one-byte or CJK
# encoding under /i or with \p{...}, and any search on UTF-16/32, now runs
# transcoded to UTF-8 with the positions mapped back (a GBK or Shift_JIS
# character's second byte may be ASCII, so the pattern is cut by the
# encoding's characters). The magic comment's ISO8859-N alias names
# ISO-8859-N. And the carriers' emoji: UTF8-/SJIS-DoCoMo, KDDI, SoftBank and
# ISO-2022-JP-KDDI, with ruby's exchange table between the companies and
# Unicode (tables measured from ruby 4.0.9, tools/gen_emoji_tables.rb).
p __ENCODING__, /x\xC1/.encoding
p(/^(\xC1)\1$/i =~ "\xE1\xC1", /^(\xE1)\1$/i =~ "\xC1\xE1", /^[\xC1]+$/i =~ "\xE1\xC1", "ab\xE1cd" =~ /\xC1c/i, $~.begin(0), $~[0].encoding, $~.pre_match)
p "\xE1\xC1\xE2".scan(/[\xC1\xC2]/i).size, "\xE1x\xC1".gsub(/\xC1/i, "-"), "\xE1-\xC1".split(/-/).size
s = "xαyΑ".encode("ISO-8859-7")
p s.index(/\xC1/i), s.rindex(/\xC1/i), s =~ /Y/i, s.match?(/\xE1Y/i)

l1 = Regexp.new("^[\xdfz]+$".force_encoding("ISO-8859-1"), Regexp::IGNORECASE)
p l1 =~ "sszzsszz".force_encoding("ISO-8859-1"), l1.encoding
k = "\xE0\xC0".force_encoding("KOI8-R"); p Regexp.new("^(\xC0)\\1$".force_encoding("KOI8-R"), Regexp::IGNORECASE) =~ k
sj = "\x82\x81a\x82\x60A".force_encoding("Shift_JIS")
p Regexp.new("(\x82\x81)(a)\\1\\2".force_encoding("Shift_JIS"), Regexp::IGNORECASE) =~ sj
gb = "\x81\x40\x81\x40".force_encoding("GBK")
p Regexp.new("(\x81@)\\1".force_encoding("GBK"), Regexp::IGNORECASE) =~ gb
u16 = "a<b&c".encode("UTF-16LE")
p u16.gsub(Regexp.new("[<&]".encode("UTF-16LE")), "<" => "&lt;".encode("UTF-16LE"), "&" => "&amp;".encode("UTF-16LE")).encode("UTF-8")

d = "\u{E63E}".force_encoding("UTF8-DoCoMo")
k = "\u{E488}".force_encoding("UTF8-KDDI")
b = "\u{E04A}".force_encoding("UTF8-SoftBank")
u = "\u{2600}".encode("UTF-8")
[d, k, b, u].each { |a| p [d, k, b, u].map { |c| (a.encode(c.encoding).b rescue $!.class) } }
p d.encode("SJIS-KDDI").b, k.encode("SJIS-KDDI").b, "\xF6\x60".force_encoding("SJIS-KDDI").encode("UTF8-KDDI").b, k.encode("ISO-2022-JP-KDDI").b
x = "\u{E6A0}".force_encoding("UTF8-DoCoMo")
p((x.encode("UTF8-KDDI") rescue [$!.class, $!.message.b, $!.source_encoding_name, $!.destination_encoding_name]), x.encode("UTF8-KDDI", undef: :replace).b, (k.encode("Windows-31J") rescue $!.class))
p [0x3042, 0x3044].pack("U*").encode("ISO-2022-JP-KDDI").b, "\e$B$\"$$\e(B".force_encoding("ISO-2022-JP-KDDI").encode("UTF8-KDDI").b
p [0x1F4BA].pack("U").encode("SJIS-KDDI", fallback: { [0x1F4BA].pack("U") => "[ISU]" })
