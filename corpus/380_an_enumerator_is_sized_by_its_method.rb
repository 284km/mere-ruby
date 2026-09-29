# An enumerator's #size is what the method that made it says -- never a count
# of a walk. Counting ran the method: keep_if's walk emptied the array, and a
# cycle never came back.
a = [1, 2, 3]
p [a.keep_if.size, a.select!.size, a.delete_if.size, a]
p [a.cycle.size, a.cycle(2).size, a.cycle(-1).size, [].cycle.size]
p [a.find.size, a.find_index.size, a.take_while.size, a.each_slice(2).size, a.each_cons(5).size]
h = {a: 1, b: 2}
p [h.select!.size, h.min_by.size, h.find.size, h]

# a program's to_enum has no size unless it gives one
p [a.to_enum.size, a.to_enum(:map).size, a.to_enum(:map) { 42 }.size]

# Enumerable methods ask the receiver's #size, and nil without one
class Bag
  include Enumerable
  def initialize(*xs) = @xs = xs
  def each(&b) = @xs.each(&b)
end
class SizedBag < Bag
  def size = @xs.size
end
[Bag.new(1, 2, 3, 4), SizedBag.new(1, 2, 3, 4)].each do |o|
  p [o.map.size, o.select.size, o.each_slice(3).size, o.each_cons(2).size,
     o.cycle.size, o.cycle(3).size, o.find.size, o.take_while.size,
     o.reverse_each.size, o.slice_before(3).size]
end

S = Struct.new(:x, :y)
p S.new(1, 2).each.size
