# The right side of a setter: a splat is an Array of its elements, and as a
# statement values after a comma make the Array too.
o = []
def o.a=(v)
  self << v
end
o.a = *0
o.a = 1, 2
o.a = [3], 4
o.a = *[5, 6], 7
p o
h = {}
h[:k] = 1, 2
h[:s] = *[3]
p h

# Parentheses a statement opens with are its target list -- once: a group
# inside that list is one element.
((a, b)) = 1, 2
p [a, b]
((*v0)) = []
p v0
((*)) = 0
(c, d) = 1, 2
p [c, d]
e, ((f, g)) = 1, [[2, 3]]
p [e, f, g]

# stateless-ISO-2022-JP is 0x92 and an EUC-JP pair; a broken sequence is
# replaced as ruby groups it.
s = "あア漢".encode("stateless-iso-2022-jp")
p s.bytes, s.valid_encoding?, s.encode("UTF-8").codepoints
["\x92\xA1x", "\xA1x", "\x92x", "\xA1\xA1\x92x"].each do |x|
  p x.encode("iso-2022-jp", "stateless-iso-2022-jp", invalid: :replace).b
end
p "\x92\xA4\xA2x".encode("iso-2022-jp", "stateless-iso-2022-jp").b

# A method the program wrote for a Time subclass is the one called --
# through send and Array#== too.
class TT457 < Time
  def ==(other) = to_i == other.to_i
end
t = TT457.at(100, 500, :millisecond)
u = Time.at(100)
p t == u, t.send(:==, u), [t] == [u], [t].include?(u)

# JSON writes a Bignum by its #to_s, which has to be a String.
require "json"
p JSON.generate([1 << 70])
pid = fork do
  Integer.class_eval { def to_s; end }
  begin
    JSON.generate(1 << 64)
    exit 1
  rescue TypeError
    exit 0
  end
end
Process.wait(pid)
p $?.success?
