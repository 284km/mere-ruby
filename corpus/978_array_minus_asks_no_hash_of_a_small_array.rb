# Array#- looks each element up with rb_eql alone when either array has 16
# elements or fewer: the same object, or the element's own #eql?. No #hash is
# asked. When both have 17 or more it builds a hash table of the array taken
# away, and then #hash is asked of both sides.
#
# ActiveRecord's `where(id: 1).or(where(id: 9223372036854775808))` computes
# `predicates - other.predicates`. The bind's #hash serializes its value and
# raises for an Integer out of range; its #eql? compares the plain values
# first and answers false. Asking #hash raised ActiveModel::RangeError.
$asked = []
class Q
  attr_reader :v
  def initialize(v) = @v = v
  def hash
    $asked << [:hash, @v]
    raise RangeError, "#{@v} out of range" if @v > 100
    @v.hash
  end
  def eql?(o)
    $asked << [:eql?, @v, o.v]
    @v == o.v
  end
  def inspect = "Q#{@v}"
end

a, b, big = Q.new(1), Q.new(2), Q.new(1000)
p [a, b] - [big]
p $asked
$asked.clear
p [a, big] - [big], $asked          # the same object: nothing is asked
$asked.clear
p [a, b] - [Q.new(2)], $asked       # equal by #eql?
$asked.clear
p [big] - [a], $asked
$asked.clear
p Array.new(3) { |i| Q.new(i) } - Array.new(16) { |i| Q.new(i + 2) }
p $asked.map(&:first).uniq
$asked.clear
# a small receiver and a long array taken away: still no #hash
p Array.new(3) { |i| Q.new(i) } - Array.new(17) { |i| Q.new(i + 2) }
p $asked.map(&:first).uniq
$asked.clear
p [a] - (Array.new(16) { |i| Q.new(i) } << big)
p $asked.map(&:first).uniq
$asked.clear
# a long receiver and a small array taken away: the same
p (Array.new(17) { |i| Q.new(i) } - [Q.new(3), big]).size
p $asked.map(&:first).uniq
$asked.clear
# both 17 or more: a hash table, so #hash is asked -- and one that raises
# is seen
p (Array.new(17) { |i| Q.new(i) } - Array.new(17) { |i| Q.new(i + 2) })
p $asked.map(&:first).uniq.sort
$asked.clear
r = begin
  Array.new(17) { |i| Q.new(i) } - (Array.new(16) { |i| Q.new(i) } << big)
rescue RangeError => e
  e.class
end
p r
# #difference is the same operation
$asked.clear
p [a, b].difference([big]), $asked.map(&:first).uniq
# values with no #eql? of their own are as before
p [1, 2, 3, 2.0] - [2], ["a", "b"] - ["b"], [[1], [2]] - [[2]], [:a, nil] - [nil]
o1 = Object.new; o2 = Object.new
p ([o1, o2] - [o2]).size, ([o1, o2] - [o2]).first.equal?(o1)
