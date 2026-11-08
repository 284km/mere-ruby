# What the rest of test/ruby/enc and test/cgi found. A UTF-16/32 string's
# chomp, count, split, ord, casecmp and gsub/sub/scan with a regexp run
# through UTF-8 and come back in the string's encoding (a replacement table
# too); a multibyte literal is one atom in a regexp of its encoding; CESU-8
# is its own shape; asciicompat_encoding answers ruby's pairs.

def show(label, v)
  v = v.encode("UTF-8") if String === v && !v.encoding.ascii_compatible?
  puts "#{label}: #{v.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

%w[UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |en|
  s = "a<b&c\n".encode(en)
  show "#{en} chomp", s.chomp
  show "#{en} chomp enc", s.chomp.encoding
  show "#{en} count", s.count("a-c".encode(en))
  show "#{en} split", "x,y,z".encode(en).split(",".encode(en)).map { |t| t.encode("UTF-8") }
  show "#{en} ord", "あb".encode(en).ord
  show "#{en} casecmp", "AbC".encode(en).casecmp("abc".encode(en))
  show "#{en} casecmp?", "AbC".encode(en).casecmp?("abc".encode(en))
  table = { "<".encode(en) => "&lt;".encode(en), "&".encode(en) => "&amp;".encode(en) }
  show "#{en} gsub table", s.gsub(Regexp.new("[<&]".encode(en)), table)
  show "#{en} gsub block", s.gsub(Regexp.new("[a-c]".encode(en))) { |m| m.upcase }
  show "#{en} sub", s.sub(Regexp.new("b".encode(en)), "B".encode(en))
  show "#{en} scan", s.scan(Regexp.new("[a-c]".encode(en))).map { |t| t.encode("UTF-8") }
end

# a multibyte literal under a quantifier, in the source's encoding and others
["EUC-JP", "Shift_JIS", "UTF-8"].each do |en|
  s = "ああ".encode(en)
  re = Regexp.new("^あ+$".encode(en))
  show "#{en} literal+", (s =~ re)
  show "#{en} hiragana", (s =~ Regexp.new("\\A\\p{Hiragana}+\\z".encode(en)))
end

# CESU-8: a supplementary character is two three-byte halves
c = "\xED\xA0\x80\xED\xB0\x80".dup.force_encoding("CESU-8")
show "cesu valid", c.valid_encoding?
show "cesu length", c.length
show "cesu ord", c.ord
show "cesu bad", "\xF0\x90\x80\x80".dup.force_encoding("CESU-8").valid_encoding?

# GB18030: chop finds the start of the last character from the left
g = "a\x81\x30\x81\x30".dup.force_encoding("GB18030")
show "gb18030 chop", g.chop.bytes
show "big5 chr", 0xA440.chr("Big5").bytes
show "cp949 chr", 0xB0A1.chr("CP949").bytes

# the encodings a non-ASCII-compatible one is worked on in
%w[UTF-16BE CESU-8 CP50220 CP50221 IBM037 ISO-2022-JP ISO-2022-JP-KDDI EUC-JP].each do |n|
  show "asciicompat #{n}", Encoding::Converter.asciicompat_encoding(n)
end

# Cyrillic small letters that fold to the U+1C80 block
show "fold 1c80", ("ᲀ" =~ /в/i)
show "fold 1c84", ("ᲄ" =~ /т/i)
show "fold te", ("т" =~ /ᲅ/i)

show "strftime utf16", (Time.at(0).utc.strftime("%Y".encode("UTF-16LE")) rescue $!.class)
