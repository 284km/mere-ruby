# Operator method names: definable, aliasable, and dispatched to.
class Bits
  def initialize(n) = @n = n
  attr_reader :n
  def >>(k) = Bits.new(@n >> k)
  def <<(k) = Bits.new(@n << k)
  def ~ = Bits.new(~@n)
  def &(o) = Bits.new(@n & o.n)
  def |(o) = Bits.new(@n | o.n)
  def >=(o) = @n >= o.n
  def to_s = "Bits(#{@n})"
  alias intersection &
  alias union |
  alias shift_r >>
  alias inspect to_s
end

a = Bits.new(12)
b = Bits.new(10)
puts a >> 2
puts a << 1
puts ~a
puts a & b
puts a.intersection(b)
puts a.union(b)
puts a.shift_r(2)
p a >= b
p ~5

# `alias name []` -- the bracket method, and the space-marked `&` above, both
# reach the same operator-name path
class Box
  def initialize = @h = { x: 1 }
  def [](k) = @h[k]
  alias fetch []
  alias key? []
end
box = Box.new
p box[:x]
p box.fetch(:x)
p box.key?(:x)

# A multiple assignment is a statement, so a paren group holding one has to
# keep parsing after the `;` -- fileutils walks a path this way.
def split_once(s)
  i = s.rindex("/")
  i ? [s[0, i], s[(i + 1)..]] : [s, s]
end

path = "/a/b/c"
list = []
until (parent, base = split_once(path); parent == path || parent == "")
  list.unshift(base)
  path = parent
end
p list
p [parent, base]

x = (p1, p2 = [7, 8]; p1 + p2)
p x
p [p1, p2]
