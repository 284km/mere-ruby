# A `:` glued to a name is a LABEL, not the start of a symbol; a keyword
# argument may omit its value (and the delimiter that says so may be on the
# next line); Hash#each yields the PAIR.
def f(a:nil, b:1, c:"x"); [a, b, c]; end
p f
p f(a:2, b:3)
p({a:1, b:2})
p({ "k": 1 })
x = true
p(x ? 1:2)
y = 5
z = 6
p(x ? y:z)
p [:a, :b]
p :sym

def kw(**o); o; end
one = 1
two = 2
p kw(one:)
p kw(
  one:
)
p kw(
  one:,
  two:
)
p kw(
  one: 9,
  two:
)

h = {"a" => 1, "b" => 2}
h.each { |pair| p pair }
h.each { |(k, v)| p [k, v] }
h.each { |k, v| p [k, v] }
h.each_pair { |(k, v)| p [k, v] }
p h.map { |k, v| "#{k}#{v}" }
p h.each_with_index.to_a

# Symbol matches a Regexp like its name does
p(:V3_2_2 =~ /\AV\d+_\d+(?:_\d+)?\z/)
p(/b/ =~ :abc)
p [:V3_2_2, :V1_8_6].sort_by { |v| v.to_s.scan(/\d+/).map(&:to_i) }

# Set is there without a require, and sort_by uses an object's own <=>
p [1, 2, 2].to_set.size
class Ver
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(o); n <=> o.n; end
end
p [Ver.new(3), Ver.new(1)].sort_by { |v| v }.map(&:n)
p [Ver.new(3), Ver.new(1)].min.n

# `a[i] = 1, 2` and `o.x = 1, 2` assign the ARRAY: the values after the comma
# grow the setter's last argument, the same as ruby's implicit array on the
# right of any assignment.
a = [1, 2, 3, 4, 5, 6]
a[3, 2] = "a", "b", "c", "d"
p a
b = [1, 2, 3]
b[0] = 7, 8
p b
c = [1, 2]
c[0..1] = 7, 8
p c
h = {}
h[:k] = 7, 8
p h
S95 = Struct.new(:v)
s = S95.new(1)
s.v = 7, 8
p s.v
p (a[0] = 9)          # the parenthesised form was already right
