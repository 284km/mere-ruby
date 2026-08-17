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
