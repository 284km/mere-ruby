# The POSIX brackets are Unicode classes: "à" is a letter, "٠" a digit,
# U+3000 a space. \w \d \s stay ASCII unless (?u) says otherwise, and \b is
# a Unicode boundary even so.
p "à".match(/[[:alnum:]]/).to_a, "٠".match(/[[:digit:]]/).to_a
p "　"[/[[:space:]]/], "\u{104D8}"[/[[:lower:]]/], "\u{104B0}"[/[[:upper:]]/]
p "«x»".scan(/[[:punct:]]/), "\u{01C5}"[/[[:word:]]/], "\u{200C}".match?(/[[:word:]]/)
p "aあ".match(/(?a)[[:alpha:]]+/).to_a, "aあ".match(/(?u)[[:alpha:]]+/).to_a
p "aあ".match(/\w+/).to_a, "aあ".match(/(?u)\w+/).to_a, "aあ".match(/(?d)\w+/).to_a
p "à" =~ /[[:^alpha:]]/, "1" =~ /[[:^alpha:]]/, "xé" =~ /x\b/, "é" =~ /\b/, "xé" =~ /(?a)x\b/
p "٣" =~ /\d/, "٣" =~ /(?u)\d/, "　" =~ /(?u)\s/

# \p{...}: general categories, scripts and the POSIX names, spelled any way
# onigmo accepts; \P and \p{^...} negate
p "a1".match(/\p{Alpha}/).to_a, "a1".match(/\p{L}/).to_a, "a۩b".match(/\p{Arabic}/).to_a
p "松本行弘 Ruby".match(/\p{Han}+/u).to_a, "Ruby（ルビー）、まつもとゆきひろ".match(/\p{Katakana}+/u).to_a
p "루비(Ruby)"[/\p{Hangul}+/], "x-ま"[/\p{Hi_ra-ga na}/], "a1"[/\P{L}/], "a1"[/\p{^N}/]
p "aB1"[/[\p{Lu}\d]+/], "A"[/\p{Ll}/i], "é" =~ /\p{Latin}/

# \X is one extended grapheme cluster
p (/\X/.match("\u{1F918}\u{1F3FD}").to_a), (/\X+/.match("\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}").to_a)
p "éx".scan(/\X/).map(&:length)

# what the class parser refuses, in ruby's words
def refusal(src)
  Regexp.new(src)
  :ok
rescue RegexpError => e
  e.message
end
p refusal("[[:etc:]]"), refusal("\\p{"), refusal("\\p{Foo}"), refusal("[\\d-z]")
p refusal("[a-\\d]"), refusal("[[:alpha:]-[:digit:]]"), refusal("[a-[:digit:]]")
p((begin; eval("/[[:etc:]]/"); rescue SyntaxError; :syntax_error; end))

# \NN: a backreference when it is <= 9 or names a group already opened,
# else \8 \9 are digits and the rest is octal
p((/\10()()()()()()()()()()/ =~ "\x08"), /\99999/.match("99999")[0], /()\18/.match("\x018").to_a)
p((/()()()()()()()()()(a)\10/.match("aa").to_a), /(a)\01/.match("a\x01").to_a, /\1()/.match(""))
p refusal("(a)\\2"), refusal("\\9"), refusal("\\400"), refusal("(?<a>a)\\1"), refusal("\\1(?<a>a)")

# conditionals: (?(n)yes|no), delimited, relative and by name
p /(a)(?(1)a|b)/.match("aa").to_a, /(a)(?(<1>)a|b)/.match("aa").to_a, /(a)(?('1')a|b)/.match("aa").to_a
p /(a)(?(<-1>)a|b)/.match("aa").to_a, /(a)(?(01)a|b)/.match("aa").to_a
p /(?<a>a)(?(<a>)a|b)/.match("aa").to_a, /(?<a>a)(?('a')a|b)/.match("aa").to_a
p /\A(foo)?(?(1)(T)|(F))\z/.match("fooT").to_a, /\A(foo)?(?(1)(T)|(F))\z/.match("F").to_a
p /\A(foo)?(?(1)(T)|(F))\z/ =~ "fooF", /(?(1)a|b)(a)/.match("ba").to_a
p refusal("(a)(?(1)a|b|c)"), refusal("(?<a>a)(?(a)a|b)"), refusal("(a)(?(2)a|b)"), refusal("(a)(?(1x)a|b)")

# a + or - after a name's first character is a level: \k<a+1> names "a"
p refusal("(?<a+1>a)\\k<a+1>"), refusal("(?<a-1>a)(?('a-1')a|b)"), /(?<a>a)\k<a+0>/.match("aa").to_a
p refusal("(a)\\k<+1>"), refusal("(a)\\k<-2>")
