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
