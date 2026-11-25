# ActiveSupport's titleize excludes letters following a word and apostrophe.
pattern = /\b(?<!\w['’`()])\p{Lower}/
["fred's", "fred’s", "d’Artagnan", "ab(c)d", "x`y"].each do |word|
  p word.gsub(pattern) { |letter| letter.upcase }
end
[
  [/(?<=表)a/, "表a"],
  [/(?<!表)a/, "表a"],
  [/(?<=(.))b/, "あb"],
  [/(?<=(a)|(あa))b/, "あab"],
  [/(?<=(a)|(ba))c/, "bac"],
  [/(?<=(a)|(ba))\2/, "baba"],
  [/(?<=(a)|(a))\2/, "aa"],
  [/(!)(?<=(a)|\g<1>)/, "!"],
  [/(?<g>表)(?<=(a)|\g<g>)/, "表"],
  [/(?<!a|表)b/, "表b"],
  [/(?<!a|表)b/, "zb"],
  [/(?<=\A|\/)x/, "x"],
  [/(?<=\A|\/)x/, "表/x"],
  [/(?<=(?<=表)a)b/, "表ab"]
].each do |regexp, string|
  match = regexp.match(string)
  p [match&.to_a, match&.begin(0)]
end
["Windows-31J", "EUC-JP", "Big5", "GBK"].each do |encoding|
  regexp = Regexp.new("(?<=(表))a".encode(encoding))
  string = "prefix表a".encode(encoding)
  match = regexp.match(string)
  p [encoding, match&.begin(0), match && match[1].bytes]
end
binary = Regexp.new("(?<=\xFF)a".b, Regexp::NOENCODING)
p binary.match("\xFFa".b)&.to_a&.map(&:bytes)

# Ambiguous trail bytes and consecutive lead-byte runs, at known boundaries.
{
  "Windows-31J" => ["\x81\x81", "\x81\x40", "\xA1"],
  "Big5" => ["\xA1\xA1", "\xA1\x40"],
  "GBK" => ["\x81\x81", "\x81\x40", "\x80"],
  "EUC-JP" => ["\xA1\xA1", "\x8F\xA2\xAF", "\x8E\xA1"]
}.each do |encoding, pieces|
  [1, 2, 5].each do |count|
    pieces.each do |tail|
      prefix = ((pieces.first * count) + tail).force_encoding(encoding)
      expression = Regexp.new("(?<=(.))x".force_encoding(encoding))
      match = expression.match(prefix + "x")
      p [encoding, count, tail.bytes, match&.begin(0), match && match[1].bytes]
    end
  end
  expression = Regexp.new("(?<!a)x".force_encoding(encoding))
  p [encoding, ("x" * 256).force_encoding(encoding).scan(expression).size]
end

# The remaining ASCII-compatible multibyte decoders must not rescan prefixes.
["CP949", "GB18030", "EUC-TW", "CESU-8"].each do |encoding|
  expression = Regexp.new("(?<!a)x".encode(encoding))
  p [encoding, ("x" * 256).encode(encoding).scan(expression).size]
end
