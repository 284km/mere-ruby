# Array#sum with Rationals among Floats, Integer#step past 2**62 and on
# bignums, a Complex whose parts are a program's Numeric, and a delegator
# as a Hash key.
require "delegate"

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# the compensated float sum keeps the small terms after a Rational
large = 100000000
small = 1e-9
small /= 10 until (large + small) == large
show("int then floats") { [large, *[small] * 10].sum }
show("rational then floats") { [large / 1r, *[small] * 10].sum }
show("float, rational, floats") { [small, large / 1r, *[small] * 10].sum }
show("rationals only") { [1/3r, 1/6r, 1/2r].sum }
show("rational then string") { [1r, "x"].sum rescue $!.class }

# step sizes past a machine int
b = 2**62
show("wide size") { (-b).step(b, 1).size }
show("wide size excl") { (-b).step(b - 1, 1).size }
show("wide by b") { (-b).step(b, b).to_a }
show("float size") { 0.0.step(2.0**62 - 1.0, 1.0).size }

# a bignum's step
big = 2**64
show("big step") { big.step(big + 2).to_a }
show("big step by") { big.step(big + 4, 2).size }
show("big step kw") { big.step(by: 2, to: big + 4).to_a }
show("big step float") { big.step(big + 1, 0.5).to_a }
show("big step block") { r = []; big.step(big + 2) { |x| r << x - big }; r }

# a Complex of a program's Numeric
class Q < Numeric
  attr_reader :n, :d
  def initialize(n, d = 1)
    g = n.gcd(d)
    @n, @d = n / g, d / g
  end
  def +(o) = o.is_a?(Q) ? Q.new(n * o.d + o.n * d, d * o.d) : self + Q.new(o)
  def -(o) = o.is_a?(Q) ? Q.new(n * o.d - o.n * d, d * o.d) : self - Q.new(o)
  def *(o) = o.is_a?(Q) ? Q.new(n * o.n, d * o.d) : self * Q.new(o)
  def quo(o) = o.is_a?(Q) ? Q.new(n * o.d, d * o.n) : quo(Q.new(o))
  alias / quo
  def -@ = Q.new(-n, d)
  def <=>(o) = (n * (o.is_a?(Q) ? o.d : 1)) <=> ((o.is_a?(Q) ? o.n : o) * d)
  include Comparable
  def ==(o) = o.is_a?(Q) ? n == o.n && d == o.d : (d == 1 && n == o)
  def abs = Q.new(n.abs, d)
  def to_f = n.to_f / d
  def coerce(o) = [Q.new(o), self]
  def inspect = "Q(#{n}/#{d})"
  alias to_s inspect
end
c = Complex(Q.new(2, 3), Q.new(1, 2))
show("neg") { -c }
show("c * c") { c * c }
show("c ** 2") { c ** 2 }
show("2 - c") { 2 - c }
show("2 / c") { 2 / c }
show("c / c") { c / c }
show("2 <=> c") { 2 <=> c }
show("c <=> c") { c <=> c }
show("plain + c") { Complex(1, 1) + c }

# a delegator is found as the key it delegates to
t = DelegateClass(String)
h = {"Int" => 1, "Float" => 2, "String" => 3, "Boolean" => 4, "WidgetFilter" => 5,
     "WidgetAggregation" => 6, "WidgetEdge" => 7, "WidgetSortOrder" => 8, "WidgetGrouping" => 9}
show("big hash") { h.keys.map { |k| h[t.new(k)] } }
small_h = {"a" => 1, "b" => 2}
show("small hash") { [small_h.key?(t.new("a")), small_h[t.new("b")], small_h[t.new("c")]] }
