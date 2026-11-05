# A search looks for the literal every match must hold first, then tries only
# the starts that can reach it; and a pattern opening with a class loop skips
# the rest of that class's run after a failed start. Neither may change an
# answer: a literal at a fixed or bounded distance, an unbounded one, a
# multibyte subject, a case-insensitive pattern (no literal), a backreference
# or \G (no run skip), and a start offset all agree with the plain search.
subjects = [
  "", "abc", "key_1 key_2 key_3999 key_3999x",
  "xxfoo@bar.com yy baz@qux.com", "abcabc@abc ab@a a@", "aaa1 bb22 c3",
  "zzz12qqq zzz qqq zz9qqq zzz777qqq", "a\nb\nkey\nc", "[ERROR] x [WARN] y [ERROR]z",
  "aaaaaaaaab" * 3, "ab" * 30 + "abc", "héllo@x éa@b key_7",
]
pats = [
  /key_3999/, /key_\d+/, /\w+@\w+\.com/, /[a-z]+@[a-z]+\.com/, /zzz\d+qqq/, /\d+qqq/,
  /.{2}y_3/, /.{0,3}y_3/, /(?<=y_)3999/, /(k)ey_(\d+)/, /x?key/, /(?:a|b)c/, /a+b/,
  /a*ab/, /\[ERROR\]/, /^key$/, /\bkey/, /(?i)KEY_\d/, /a(?=b)b/, /(?!x)key/, /ab{2,}/,
  /abc\z/, /(a|bc)+c/, /key_(?:39)+99/, /(?<n>key)_\k<n>/, /.*key/, /.+?key/, /\Gkey/,
  /(?>a+)b/, /a{3}b/, /[a-z]+@/, /\w+\d/, /[a-z]+?@/, /([a-z]+)@\1/, /[a-z]{2,}q/,
  /[a-z]+(?<=c)d/, /[a-zé]+@/, /[a-z]*@/, /(?:[a-z])+@/, /[a-z]+\b/, /[a-z]+(?=@)/,
  /(?<w>[a-z]+)@/, /[^@ ]+@\w/, /[a-z]+(?:@|\d)/,
]
subjects.each do |s|
  pats.each do |re|
    r = [s =~ re, $~ && $~.to_a, s.scan(re), s.gsub(re, "<\\0>"), s.split(re),
         s.index(re, 3), s.match?(re), s.sub(re) { $~.begin(0).to_s }]
    r << s.rindex(re) << s.rindex(re, 5) if s.ascii_only?
    puts "#{s[0, 12].inspect} #{re.inspect} #{r.inspect}"
  end
end
b = "xx\xffkey_3999\xfe".b
p [b =~ /key_3999/n, b.scan(/.y_3/n), b.index(/key/n, 2)]
l = "\xe9t\xe9 key_1".force_encoding("ISO-8859-1")
p [l =~ /key_1/, l.scan(/.key/), l.index(/t.\s?key/)]
e = "あいkey_3".encode("EUC-JP")
p [e =~ Regexp.new("key".encode("EUC-JP")), e.index(Regexp.new("い.ey".encode("EUC-JP")))]
p "abc key_3999".match(/key_3999/, 4)&.begin(0), "abc key_3999".match(/key_3999/, 5)
p "abc key_3999".index(/key/), "abc key_3999".partition(/y_\d+/), "abc key_3999".rpartition(/k/)
