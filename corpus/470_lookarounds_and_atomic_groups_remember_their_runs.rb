# A run inside an atomic group or a lookahead remembers where each state led:
# these were quadratic (a million a's out of reach).
s = "a" * 200_000 + "x"
p(/^a*?(?>a*a*)$/ =~ s)
p(/^a*?(?=a*a*)$/ =~ s)
p(/^a*?(?!a*a*)$/ =~ s)
p(/^a*?(?>a*a*)x$/ =~ s)

# a lookahead nested in an atomic group answers for its own run, not the
# outer one (this can never match; taking the outer end, it found [3, 4])
re = /(?>(?:(?:a|ab)(?:[^a]a*?)*[ab])+(?=(?=b*b+?))(?!(?:a|b)))(?>[ab](?:a|b))/
p re.match("ccaacacacaaaaaababcacbaaacbaccbacbbacacbabaacaaacaaaaa")
p re.match("abba")

# empty turns of a loop inside a lookahead or an atomic group still end
p(/(?=(?:a|b?)*b)/ =~ "aabaac")
p(/(?=(?:a?b?)*?c)a/ =~ "aabaac")
p(/(?>(?:a|b?)*)c/ =~ "aabaac")
p "aaba".scan(/(?=(?:a|ab)*b)a/)
p "abcab".gsub(/(?!(?:a|b)*c)./, "-")
