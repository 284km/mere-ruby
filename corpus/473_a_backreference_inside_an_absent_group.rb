# A backreference inside an absent group (?~...) to a group outside it reads
# what that group captured: the absent group's inner match runs where the
# outer captures are. It ran from empty captures before, so \1 matched nothing
# and (?~\1) excluded nothing -- the whole rest of the string.
[
  [/(a)(?~\1)/, "aab"], [/(a)(?~\1)/, "abab"], [/(a)(?~\1)b/, "acab"],
  [/(ab)(?~\1)/, "abxxabyy"], [/(.)(?~\1)\1/, "abcab"], [/(x)?(?~\1)/, "yyx"],
  [/(a|b)(?~\1)$/, "abba"], [/(?<n>q)(?~\k<n>)z/, "qwqz"], [/(a)(?~\1)/, "aaa"],
  [/^(\w)(?~\1)\1$/, "abca"], [/(\w)(?~\1)/, "hello"],
].each do |re, s|
  m = re.match(s)
  p [s, m && m.to_a, m && m.begin(0)]
end
