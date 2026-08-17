# `.` in a regexp is one CHARACTER, not one byte. The matcher walks bytes, so on
# a UTF-8 string it used to consume a single byte of a multibyte character:
# "こんにちは"[/に./] came back as "に\xE3" -- the first byte of what should have
# been the next character, which is not even a valid string.
str = "こんにちは"
p str[/に./]
p str.slice(/に./)
p str[/に./, 0]
p str[/に(.)/, 1]
p str[/zzz/]
p str.sub(/に./, "X")
p str.gsub(/./, "-")
p str.scan(/./).length
p "aあbい"[/a.b/]
p "aあb"[/a.b/]

# An index that is not an index. Every argument that was not an Integer, a
# Range, a Regexp or a String came back as nil, so `"abc"[Object.new]` was a
# value where Ruby raises.
s = "abc"
[1, 1.0, 1.7, -1.0, "b"].each { |a| p s[a] }
[Float::INFINITY, -Float::INFINITY, Float::NAN, 2**70].each do |a|
  begin
    s[a]
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
[:sym, nil, Object.new].each do |a|
  begin
    s[a]
  rescue => e
    puts e.class
  end
end
p s.slice(1.9, 1)

# Every position Ruby reports is a CHARACTER index -- =~, index, rindex,
# MatchData#begin/#end. This engine works in bytes, so on a multibyte string
# they came back as byte offsets: "日本語abc".index("a") was 9 where Ruby says 3.
# On an ASCII string the two are equal, which is why it never showed.
t = "日本語abc"
p(t =~ /語/)
p t.index(/語/)
p t.index("語")
p t.index("a")
p t.index("語", 1)
p t.rindex("語")
p t.index("zz")
m = t.match(/語(a)/)
p m.begin(0)
p m.end(0)
p m.begin(1)
p m.end(1)

# character classes are characters too, and an empty match steps a character
u = "こんにちは"
p u[/[あ-ん]/]
p u[/[^a]/]
p u.gsub(/[^ん]/, "-")
p u.split(//).length
p u.split(//) == u.chars
p "тест"[/[а-я]+/]
p "aあb"[/a.b/]
