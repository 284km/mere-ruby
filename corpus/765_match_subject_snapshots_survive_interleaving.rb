# Interleaving subjects must retain each MatchData's own immutable input.
source = "é:name=alpha;tail"
saved = []
4.times do |i|
  match = /(?<key>name)=(?<value>[^;]+)/.match(source)
  saved << match
  /(?<other>other)/ =~ "other"
  p [other, $~[0], match[:key], match[:value], match.byteoffset(0)]
  source.replace("é:name=value#{i};tail")
end
GC.start
p saved.map { |m| [m.string, m.string.encoding, m.string.frozen?, m[0], m.pre_match, m.post_match] }
[Encoding::UTF_8, Encoding::ASCII_8BIT, Encoding::ISO_8859_1].each do |encoding|
  text = "name=alpha".dup.force_encoding(encoding)
  /(?<name>alpha)/ =~ text
  p [name, name.encoding, $~.string.encoding]
  /(?<name>absent)/ =~ text
  p [name, $~]
end
large = ("a" * 8192 + "z").freeze
matches = 8.times.map do
  m = /(a)(z)/.match(large)
  /tiny/.match("tiny")
  m
end
GC.start
p matches.map { |m| [m.string.bytesize, m.string.frozen?, m.captures, m.byteoffset(0), m.pre_match.bytesize] }
