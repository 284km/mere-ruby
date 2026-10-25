# Characters in wide and in four-byte encodings, a bignum's low byte, a dump
# that a frozen literal can evaluate, and a nameless match asked for a name

%w[UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |e|
  s = "abcdef".encode(e)
  p [e, s.index("def".encode(e)), s.rindex("def".encode(e)), s.byteindex("def".encode(e)), s.index("def".encode(e), 2)]
end

s = "\xE3\x81\x82".dup
[-1, 0x100, 0x4f7574206f6620636861722072616e6765].each { |v| p [s.setbyte(0, v), s.getbyte(0)] }

["あ".encode("UTF-16LE"), "あ".encode("UTF-32BE"), "a\xff".dup.force_encoding("EUC-JP")].each do |str|
  d = str.dump
  p d, eval(d) == str, d.undump == str, eval("# frozen-string-literal: true\n#{d}") == str
end

g = "\x81\x30\x81\x30".dup.force_encoding("GB18030")
p g.valid_encoding?, g.length, g.inspect, "\x81\x30\x81".dup.force_encoding("GB18030").valid_encoding?
p "a\x81\x40b".dup.force_encoding("GB18030").chars.size

%w[US-ASCII UTF-8 EUC-JP Windows-31J ISO-8859-1].each do |e|
  f = "%p".dup.force_encoding(e)
  p [e, (f % "a".dup.force_encoding(e)).encoding]
end

"abc".sub("a", "")
m = $~
key = "\u{3042}"
[Encoding::UTF_8, Encoding::Shift_JIS, Encoding::EUC_JP].each do |enc|
  idx = key.encode(enc)
  begin
    m[idx]
  rescue IndexError => e
    p [enc, e.message.encoding, e.message.end_with?(idx)]
  end
end
