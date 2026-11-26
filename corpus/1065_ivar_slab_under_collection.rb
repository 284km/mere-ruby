# Objects' instance variables across collections (note 559 step 2b): many
# objects made and dropped, their variables' space reused; an object with a
# hundred variables; a Struct with members and variables; values that are
# themselves objects, kept alive only through a variable.
class N1065
  attr_accessor :v, :nx
  def initialize(v, nx); @v = v; @nx = nx; end
end
head = nil
1000.times { |i| head = N1065.new(i, head) }
GC.start
sum = 0
n = head
while n
  sum += n.v
  n = n.nx
end
p sum

3.times do |round|
  junk = (1..20000).map { |i| o = Object.new; o.instance_variable_set(:@x, i); o.instance_variable_set(:@y, "s#{i}"); o }
  junk = nil
  GC.start
end
keep = (1..5000).map { |i| o = Object.new; o.instance_variable_set(:@x, i); o.instance_variable_set(:@y, i.to_s); o }
GC.start
p keep.sum { |o| o.instance_variable_get(:@x) }, keep[4321].instance_variable_get(:@y)

big = Object.new
100.times { |i| big.instance_variable_set("@v#{i}", "x" * (i % 7)) }
GC.start
p big.instance_variables.size, big.instance_variables.last, big.instance_variable_get(:@v99)
big.remove_instance_variable(:@v50)
GC.start
p big.instance_variables.size, big.instance_variable_defined?(:@v50), big.dup.instance_variables.size

S1065 = Struct.new(:p, :q)
s = S1065.new([1], "two")
s.instance_variable_set(:@extra, { k: 3 })
GC.start
t = s.dup
p s.instance_variables, t.p, t.q, t.instance_variable_get(:@extra)

# removed, then the object dropped: nothing of it is read again
r = Object.new
r.instance_variable_set(:@a, "kept?")
r.remove_instance_variable(:@a)
r = nil
GC.start
fresh = Object.new
fresh.instance_variable_set(:@a, "fresh")
p fresh.instance_variables, fresh.instance_variable_get(:@a)
