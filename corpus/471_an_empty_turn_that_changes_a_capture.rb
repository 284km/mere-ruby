# A loop turn that consumes nothing but changes a capture runs once more --
# back at the loop's split, at the position it entered from. The match
# cache had marked that split on the way in, and took the turn for failed.
def show(re, s) m = s.match(re); m ? [m.offset(0), m.captures] : nil end
p show(/(a*)+.(a*)?$/, "aacac")
p show(/(a*)+.(a*)?$/, "acabaabaccaacaaaaaaaaaaacaaaaa")
p show(/(a*)+.(a*)?$/, "ac")
p show(/(a*)+b/, "aaab")
p show(/(a|)+b/, "xaaab")
p show(/((ab)*)+$/, "cabab")

# what the turn changed is what the capture holds after it, not a value it
# passed through on the way
p show(/(?:(?=(a)|(b))|x)+/, "bbc")
p show(/(?:(?=(a+?)*)|x)+$/, "aab")
p show(/(?:b?(?=(a+?)*?))+c/, "bbc")
p show(/(?:b?(?=(a+?)*?))+c/, "aac")
