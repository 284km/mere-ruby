# The last regexp search's pattern, key and lookups, and the encoding cut's
# slot, are kept in tables of their own arena that the collector compacts
# (note 559 §10: in the default region a write left the old copy behind,
# 134 MB in a YAML.load of 16,384 rows). A collection can come in the middle
# of a search -- a gsub's block runs between its matches -- and the outer
# search goes on with what it looked up before.
s = "alpha beta gamma delta epsilon " * 3
b = s.b
inner = 0
out = s.gsub(/[a-z]a\b/) do |m|
  GC.start
  inner += 1 if b =~ /gam+a/ && "zeta".index(/et/) && s.match?(/ps/)
  b.index(/lon/)
  m.upcase
end
p out, inner, $~.nil?
# patterns taking turns, a binary subject among them, collected every turn
hits = (1..200).map do |i|
  GC.start if i % 17 == 0
  r = i.even? ? /bet(a)/ : /(del)ta/
  m = (i % 3 == 0 ? b : s).match(r)
  [m[1], m.pre_match.size, m.string.encoding.to_s]
end
p hits.uniq, hits.size
p s.scan(/[a-z]+a\b/).tally, b.scan(/e[a-z]/).size
p "café naïve".scan(/\p{L}+/), "café".b.scan(/./n).size
