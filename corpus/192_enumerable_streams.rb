# An Enumerable method drives the receiver's own #each rather than a copy of
# it, and the difference is visible in two places: what a multi-value yield
# hands the block, and how far the walk gets.

class Multi
  include Enumerable
  def each
    yield 1, 2
    yield 3, 4, 5
    yield 6
  end
end

m = Multi.new
p m.to_a                              # gathered: [[1, 2], [3, 4, 5], 6]
p m.map { |x| x }                     # ...but the block is given the ARGUMENTS
p m.map { |x, y| [x, y] }
p m.count
p [m.all? { |x| x }, m.any? { |x| x.nil? }, m.none? { |x| x.nil? }, m.one? { |x| x == 6 }]
p m.each_with_index.to_a
p m.each_entry.to_a
# ...and these five PACK the values before the block sees them, as ruby does
p m.select { |x| x }
p m.reject { |x| x.nil? }
p m.find { |x| x == 6 }
p m.drop_while { |x| x != 6 }
p m.sort_by { |x| x.to_s }
p m.group_by { |x| x.class }
p m.partition { |x| x.is_a?(Integer) }
p m.min_by { |x| x.to_s }
p m.max_by { |x| x.to_s }

# the walk stops when the answer is known
class Counting
  include Enumerable
  attr_reader :walked
  def initialize; @walked = 0; end
  def each; [1, 2, 3, 4, 5].each { |x| @walked += 1; yield x }; end
end
def walked
  c = Counting.new
  yield c
  c.walked
end
p walked { |c| c.take_while { |x| x < 3 } }
p walked { |c| c.first }
p walked { |c| c.find { |x| x == 2 } }
p walked { |c| c.any? { |x| x == 1 } }
p walked { |c| c.take(2) }
p walked { |c| c.include?(3) }

# a Set refuses to grow while it is being walked -- which only a walk that is
# actually happening can notice.
require "set"
s = Set[:a, :b]
begin
  s.map { s.add(:c) }
rescue RuntimeError => e
  p e.message
end

# the surface, on a receiver of one's own
class Pairs
  include Enumerable
  def each(*outer)
    p [:each_got, outer] unless outer.empty?
    yield [:a, 1]
    yield [:b, 2]
    yield [:a, 3]
  end
end
pr = Pairs.new
p pr.to_h
p pr.to_a(:forwarded)
p pr.each_slice(2).to_a
p pr.each_cons(2).to_a
p pr.zip([9, 8, 7])
p pr.tally.size
p pr.inject(0) { |acc, _| acc + 1 }
p pr.sum([]) { |x| [x[0]] }
p pr.each_with_object([]) { |x, acc| acc << x[0] }
p pr.chunk_while { |a, b| a[0] == b[0] }.to_a
p pr.filter_map { |x| x[0] if x[1].odd? }
p pr.min_by { |x| x[1] }
p pr.flat_map { |x| x }
p pr.cycle(2).to_a.size

# what it refuses
def refusal
  yield
  :no_refusal
rescue StandardError => e
  [e.class, e.message]
end
p refusal { Multi.new.take(-1) }
p refusal { Multi.new.drop(Object.new) }
p refusal { Multi.new.each_slice(0) }
p refusal { Multi.new.first(2**100) }
p refusal { Multi.new.all?(1, 2) }
p refusal { Multi.new.count(1, 2) }

# `it`, the block parameter that needs no bar
p [1, 2, 3].map { it * 2 }
p [[1, 2]].map { it.first }
it = :a_real_local
p [1].map { it }

# and the small names
p [1, 2, 3].fetch_values(0, 2)
p([1].fetch_values(5) { |i| i * 3 })
p proc { }.binding.class
p String.instance_method(:to_s).super_method
p 1.0.coerce("2")
p Float("1.")
