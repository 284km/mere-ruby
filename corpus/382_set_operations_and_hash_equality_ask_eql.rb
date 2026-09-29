# Array's set operations and a Hash's keys are about eql?, not ==:
# 1 and 1.0 are equal and are not the same element or the same key.
p [5.0, 4.0] & [5, 4], [5.0, 4.0] | [5, 4], [5.0, 4.0] - [5, 4]
p [5.0, 4.0].union([5, 4]), [5.0, 4.0].intersection([5, 4]), [5.0, 4.0].difference([5, 4])
p [[1], [1.0]].uniq
p({1 => "x"} == {1.0 => "x"}, {1 => 1} == {1 => 1.0}, {1 => 1}.eql?({1 => 1.0}))
h = {}; h[:a] = h
g = {}; g[:a] = g
p [h == g, h.eql?(g)]

# the element being looked for is the one asked: x.eql?(y), x from the receiver
class Key
  attr_reader :n
  def initialize(n) = @n = n
  def hash = 0
  def eql?(o) = o.is_a?(Key) && n == o.n
end
a, b = Key.new(1), Key.new(1)
p [([a] - [b]).size, ([a] & [b]).size, ([a] | [b]).size]
p({a => 1} == {b => 1})

# an operand is converted with #to_ary / #to_hash, or refused in ruby's words
o = Object.new
def o.to_ary = [2, 3]
p [1, 2, 3] - o, [1, 2, 3] & o, [1, 2] | o, [1, 2].union(o)
begin; [1, 2] & Object.new; rescue TypeError => e; p e.message; end
t = Object.new
def t.to_hash = {a: 1}
p({a: 1, b: 2} > t, {a: 1} <= t)
begin; Hash[[:a]]; rescue ArgumentError => e; p e.message; end
begin; Hash[[[:a, 1], 42]]; rescue ArgumentError => e; p e.message; end
p({a: 1}.freeze.transform_keys!.class)
