# A character class without /i answers an ASCII byte from a table, and `.`
# steps over one without decoding -- where a byte below 0x80 is a character
# by itself: in UTF-8 and in a one-byte encoding. In Shift_JIS a byte below
# 0x80 can be the second half of a character, and the class must still be
# asked of the whole character there.

def show(label, s, re)
  r = s.scan(re)
  puts "#{label}: #{r.map { |x| x.is_a?(Array) ? x.map(&:inspect).join("/") : x.inspect }.join(" ")}"
end

u = "ab1 _Z\té9-x\ny"
show "word utf8", u, /\w+/
show "nonword utf8", u, /\W/
show "digit utf8", u, /[[:digit:]]/
show "range utf8", u, /[a-z]+/
show "negated utf8", u, /[^a-z\s]/
show "space utf8", u, /\s/
show "posix utf8", u, /[[:punct:]]/
show "dot utf8", u, /.{3}/
show "dot multiline", u, /.{3}/m
show "dot newline", "a\nb", /a.b/
show "dot newline m", "a\nb", /a.b/m
show "nested class", u, /[a-z&&[^b]]+/
show "property", u, /\p{Alpha}+/
show "ci class", "aBcKKk", /[a-c]+|[k]+/i

b = "ab\xE9\x01z9".b
show "word binary", b, /\w+/n
show "negated binary", b, /[^a-z]/n
show "dot binary", b, /./n

l = "caf\xE9 x1".force_encoding("ISO-8859-1")
show "word latin1", l, Regexp.new("[a-z]+".encode("ISO-8859-1"))
show "negated latin1", l, Regexp.new("[^a-z ]".encode("ISO-8859-1"))

# "表" in Shift_JIS is 0x95 0x5C: its second byte is "\" in ASCII
sj = "a表b\\".encode("Shift_JIS")
show "sjis backslash", sj, Regexp.new("\\\\".encode("Shift_JIS"))
show "sjis negated", sj, Regexp.new("[^ab]".encode("Shift_JIS"))
show "sjis dot", sj, Regexp.new(".".encode("Shift_JIS"))
show "sjis range", sj, Regexp.new("[a-z]".encode("Shift_JIS"))

e = "xあy".encode("EUC-JP")
show "eucjp negated", e, Regexp.new("[^xy]".encode("EUC-JP"))
show "eucjp dot", e, Regexp.new(".".encode("EUC-JP"))

p "a1b22c333".gsub(/\d+/) { |m| m.size.to_s }
p "key=value, k2=v2".scan(/(\w+)=(\w+)/)
p "x,y;  z".split(/[,;]\s*/)
