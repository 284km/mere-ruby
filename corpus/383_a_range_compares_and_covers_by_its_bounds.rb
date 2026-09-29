# Range#== / #eql? compare the bounds by their own == / eql?, and a Range
# subclass instance is a range like any other.
class Len
  include Comparable
  attr_reader :n
  def initialize(n) = @n = n
  def ==(o) = o.is_a?(Len) && n == o.n
  def eql?(o) = self == o
  def <=>(o) = n <=> o.n
end
class MyRange < Range; end
p (Len.new(3)..Len.new(5)) == (Len.new(3)..Len.new(5))
p (Len.new(3)..Len.new(5)).eql?(Len.new(3)..Len.new(5))
p [(1..2) == MyRange.new(1, 2), (1..2).eql?(MyRange.new(1, 2)), (0..1).eql?(0..1.0), (0..1) == (0..1.0)]

# cover? takes a range: is the whole of it inside?
p [(0..10).cover?(3..7), (0..10).cover?(3..15), (0...10).cover?(0...10), (0...10).cover?(0..9)]
p [(0..10).cover?("a".."z"), ("c".."i").cover?("d".."f"), (1..).cover?(2..), (..5).cover?(..3)]

# the BEGIN's <=> decides the low side, and a number asks the other's coerce
o = Object.new
def o.coerce(x) = [x, 3]
def o.<=>(x) = 1
p (1..5).cover?(o)

# an object range is checked with <=> when it is made, even obj..obj
seen = []
t = Object.new
t.define_singleton_method(:<=>) { |x| seen << :cmp; 0 }
r = (t..t)
p seen
p (t..t).step(t).size
