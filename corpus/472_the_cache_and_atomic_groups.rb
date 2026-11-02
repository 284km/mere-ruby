# The match cache is refused for a capture inside an atomic group (as Onigmo
# refuses it), not for an atomic group and an empty-able loop anywhere in the
# pattern: these two ran out of their budget where ruby answers at once.
# (Bug #20886 is still refused: test_regexp's test_bug_20886.)
re = Regexp.new("(?:(?:a*(?>.))*[^a](?=[^a](?:(?:a|b))*?(?:b?.)+?))?$")
s = "cacacacaaabaabcacaccaaaaaaaaabcbcbaaacabcccbcbabcaaaaacaaabaabaacaacabbbaaaaacccaaaaaaaabccaaabaabaaaacababaaababaaabcaacacaacaaaabaaaacaacacaacabcaaabaaaaaaaaaaaaaccaaaabbaaaaaaaccabaaabccaacaaaaaaababaaaacacaacaacaabaaaccaabbaabaaacbaaabaaababaacbbccaccbbaaaccbcacabcaaab"
p re.match(s)&.offset(0)
re = Regexp.new("^(?:(?:(?>a)(?:a|b)(?:(?:ab)*.a?)+?)+)?(?=(?:(?:(?:ab)*(?:ab)*)+?(?:a|b))*)(?:a|b)$")
s = "abacbaababbcbacaaaaaaabaaacaaacaaaaaacababbabaabacbaaaaaaacacbabcacacbaacaaaacbabbbacaaaacaabcacbcababcaacccaabaaaacaabbcccbacbcbabbaaacaacaaabbbabaaabaaacacaaabaabcbabbbaaaaaaabccaaaaaababaaabacaaaaabacaaccabaaababaacccabacabaaabacaccaaaaabacabaaaaaacbabaaabacaaax"
p re.match(s)&.offset(0)


# Bug #20886's pattern has no cache, and its search is cubic; but a subject
# with neither a d nor a b holds nothing it could match, and ruby says so at
# once (a character every match must contain)
p(/d()*+|a*a*bc/ =~ "a" * 20000 + "x")
p(/d()*+|a*a*bc/ =~ "a" * 20000 + "cx")
