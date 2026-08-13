# A lookbehind's alternatives may have DIFFERENT fixed lengths; the matcher
# tries each start position and requires the body to end where the lookbehind
# is, so the branch that fits wins.
p ("/ab" =~ /(?<=\A|\/)ab/)
p ("xab" =~ /(?<=\A|\/)ab/)
p "a.b-c".scan(/(?<=^|[\/.-])\w/)
p ("abcd" =~ /(?<=abc|bc)d/)
p ("bcd" =~ /(?<=abc|bc)d/)
p ("cd" =~ /(?<=abc|bc)d/)
p ("ab" =~ /(?<!a|xy)b/)
p ("xyb" =~ /(?<!a|xy)b/)
p ("zb" =~ /(?<!a|xy)b/)
p "don't stop-me now".gsub(/(?<!\w['’`(\[{])\b\w/) { |m| m.upcase }
p "one two".gsub(/(?<=\s)(\w)/) { $1.upcase }
p ("abc" =~ /(?<=(?<=a)b)c/)
p ("xbc" =~ /(?<=(?<=a)b)c/)
p "aXbXc".split(/(?<=X)/)
