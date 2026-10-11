# An interpolated string is built in one pass, and a String-replacement gsub
# publishes $~ once, for its last match (note 308). What either can observe:

# interpolation keeps each piece's encoding and refuses an incompatible pair
b = "\xff".b
u = "あ"
p "x#{b}".encoding, "#{u}".encoding, "#{b}y".encoding
begin
  "#{u}#{"\xff".b}"
rescue => e
  p e.class, e.message
end
p "a#{nil}b#{:sym}c#{1.5}d#{[1, 2]}e#{{k: 1}}"
o = Object.new
def o.to_s = "OBJ"
p "<#{o}>"
o2 = Object.new
def o2.to_s = 42
p "<#{o2}>".sub(/0x\h+/, "ADDR")
s = "abc"
r = "#{s}"
p r.equal?(s), r.frozen?, r
e = "あ".encode("EUC-JP")
p "#{e}".encoding, "x#{e}".encoding

# gsub / sub leave $~ holding the last match, with its groups and its
# pre_match / post_match; a miss leaves nil
t = "hello world"
p t.gsub(/(o)(.)?/, '<\1\2>'), $~[0], $1, $2, $~.pre_match, $~.post_match, $`, $'
p t.gsub(/zzz/, ""), $~
p "abc".sub(/b/, '[\0]'), $~[0], $&
p t.gsub(/o/, "o" => "0"), $~[0]
h = Hash.new { |_, k| $~ ? $~.begin(0).to_s : "?" }
p t.gsub(/o/, h)
s2 = +"aaa"
p s2.gsub!(/a/, "b"), $~.begin(0)
p s2.gsub!(/z/, ""), $~
p "a1b22c333".gsub(/\d+/) { |m| "(#{m.size}@#{$~.begin(0)})" }
