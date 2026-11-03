# A search that walks hundreds of millions of steps, with captures in
# lookaheads, so neither the match cache nor the lookaround memo bounds it
# (ruby answers nil in 5 s; this VM reaches its step budget). Its choices
# used to be a list consed at every split and kept until the search ended:
# 1.6 GB at a budget of 20 million steps. A run now holds what is live (the
# slots in a table with a trail, the choices as ints), at any step count.
#
#   ./tools/rx_budget_rss_check.sh [path/to/mere-ruby]
re = Regexp.new("(?=a*[ab](?>(c(a|ab)b?)?(?>(a|b))))(?>(a*(ca?)*?)+?(?>(?!b?.))(?>(?=(a|b))(?>(a|b)a*)(?>b*b*a*?)))a?$")
s = "abaacabcabaacbcabaaabcaacaaaaabcaaaacaababaabaaacabcacaacaaacbaaacaaaaabcbabbbacbcaaacaacacacaacaababaaacacaabaaaaaaabaaaaaaaababbaacacaacabcaabbabaaaabaaaacaaababbbaccabcccccbcbaaabbabacb"
r = begin; re.match(s) ? :hit : :miss; rescue Regexp::TimeoutError; :timeout; end
p r
