# frozen_string_literal: true
#
# A String a literal Hash or Array holds is ruby's fstring: one object for
# that text, whichever literal it is written in. ruby compiles `{"ABC" => 1}`
# to one instruction that copies a Hash made at compile time, and that
# Hash's key is the fstring -- so two such literals share the key object,
# and the key is `"ABC".freeze`.
#
# On the ISeq VM each literal's Strings were objects of their own.
a = {"ABC" => :t}
b = {"ABC" => :t}
p a.keys[0].equal?(b.keys[0]), "ABC".equal?(a.keys[0]), a.keys[0].frozen?
def keys_of = {"k1" => 1, "k2" => [2], nil => 3}.keys
p keys_of[0].equal?(keys_of[0]), keys_of[0].equal?("k1"), keys_of[1].equal?({"k2" => 0}.keys[0])
# ...a value too, and what an Array holds
c = {x: "val", y: ["in", "ner"]}
d = {z: "val"}
p c[:x].equal?(d[:z]), c[:x].equal?("val"), c[:y][0].equal?("in")
e = ["one", "two", :s, 3]
f = ["one", "two"]
p e[0].equal?(f[0]), e[1].equal?("two"), e.frozen?, e[0].frozen?
p [["deep", ["er"]]][0][1][0].equal?("er")
# a `case` over Strings finds its branch by them
def pick(s)
  case s
  when "one" then 1
  when "two", "three" then 2
  else 0
  end
end
p pick("one"), pick(+"three"), pick("four"), pick(:one)
# a key that is not a literal is copied and frozen, and is the fstring too
var = +"ABC"
g = {var => 1}
p g.keys[0].equal?("ABC"), g.keys[0].equal?(var), var.frozen?
h = {}
h[+"dyn"] = 1
p h.keys[0].equal?("dyn")
# without the magic comment a literal key is still the fstring
p eval(<<~'RUBY')
  # frozen_string_literal: false
  i = {"plain" => 1}
  j = {"plain" => 2}
  [i.keys[0].equal?(j.keys[0]), i.keys[0].frozen?, "plain".frozen?, "plain".equal?("plain"), "plain".freeze.equal?(i.keys[0])]
RUBY
