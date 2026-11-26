# ActiveSupport's titleize excludes letters following a word and apostrophe.
pattern = /\b(?<!\w['’`()])\p{Lower}/
["fred's", "fred’s", "d’Artagnan", "ab(c)d", "x`y"].each do |word|
  p word.gsub(pattern) { |letter| letter.upcase }
end
# A Unicode escape list emits one flat run, even for multiple characters.
p /(?<=\u{65E5 672C})x/.match("日本x")&.begin(0)
p /(?<=\u{65E5 61})x/.match("日ax")&.begin(0)
p /(?<!\u{65E5 672C})x/.match("日本x")&.begin(0)
[
  [/(?<=\u{61 65E5})x/, "a日x"],
  [/(?<!\u{61 65E5})x/, "a日x"],
  [/(?<=\u{65E5 672C 8A9E})x/, "日本語x"],
  [/(?<!\u{65E5 672C 8A9E})x/, "日本語x"],
  [/(?<=\u{1F600 65E5})x/, "😀日x"],
  [/(?<=\u{65E5 1F600})x/, "日😀x"],
  [/(?<=\A\xE6\x97\xA5)x/, "日x"],
  [/(?<!\A\xE6\x97\xA5)x/, "日x"],
  [/(?<=[ab]\xE6\x97\xA5)x/, "a日x"]
].each { |regexp, string| p regexp.match(string)&.begin(0) }
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

# Each decoder's non-ASCII boundary must capture one complete character.
[
  ["CP949", "\x81\x81" * 5],
  ["CP949", "\x81\x81" * 5 + "\x81\x41"],
  ["EUC-TW", "\xA1\xA1" * 3],
  ["GB18030", "\x81\x40" * 3],
  ["GB18030", "\x81\x30\x81\x30" * 3],
  ["CESU-8", "\xE8\xA1\xA8" * 3],
  ["CESU-8", "\xED\xA0\x80\xED\xB0\x80" * 3]
].each do |encoding, bytes|
  prefix = bytes.force_encoding(encoding)
  expression = Regexp.new("(?<=(.))x".force_encoding(encoding))
  match = expression.match(prefix + "x")
  p [encoding, prefix.valid_encoding?, match&.begin(0), match && match[1].bytes]
end

# Pattern literals also have character widths, including CESU-8 pairs.
[
  ["UTF-8", [0xF0,0x90,0x80,0x80]],
  ["GB18030", [0x81,0x30,0x81,0x30]],
  ["CESU-8", [0xED,0xA0,0x80,0xED,0xB0,0x80]]
].each do |encoding, bytes|
  atom = bytes.pack("C*").force_encoding(encoding)
  ["(?<=", "(?<!"].each do |start|
    source = (start.b + atom.b + ")b".b).force_encoding(encoding)
    subject = (atom.b + "b").force_encoding(encoding)
    begin
      match = Regexp.new(source).match(subject)
      p [encoding, start, source.valid_encoding?, match && match[0].bytes]
    rescue StandardError => error
      p [encoding, start, error.class, error.message]
    end
  end
end
