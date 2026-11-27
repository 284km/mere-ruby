# The instance variables' slab is squeezed after a collection finds it more
# than twice its live areas: the live areas move to its start, each record
# gets its new base, and the rest goes back. Every object's variables are
# where they were said to be -- read, written, added, removed -- after it.
class P1075
  def initialize(i) = (@a = i; @b = i.to_s; @c = [i]; @d = nil)
  attr_reader :a, :b, :c, :d
end
class Q1075
  def initialize(i) = (@x = i; @y = i * 2)
  attr_reader :x, :y
end
def burst_1075(n) = (0...n).map { |i| P1075.new(i) }.size
def churn_1075(n) = (0...n).map { |i| Q1075.new(i) }.size

keep = (0...2000).map { |i| P1075.new(i) }
s = "str"; s.instance_variable_set(:@on_string, [1, 2])
burst_1075(120_000)
GC.start
x = 0
GC.start
more = (0...3000).map { |i| Q1075.new(i) }
p keep.each_with_index.all? { |o, i| o.a == i && o.b == i.to_s && o.c == [i] && o.d.nil? }
p more.each_with_index.all? { |o, i| o.x == i && o.y == 2 * i }
p s.instance_variable_get(:@on_string)
keep[5].instance_variable_set(:@e, :added)
keep[6].remove_instance_variable(:@d)
p keep[5].instance_variables, keep[5].instance_variable_get(:@e), keep[6].instance_variables
10.times { churn_1075(10_000); GC.start }
p keep.sum(&:a), more.sum(&:y), keep[5].instance_variable_get(:@e), keep[7].c
