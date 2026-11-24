# A key that defines #hash and #eql? is ONE key to every method that builds a
# table, not only to `h[k] = v` and a hash literal. Array#group_by, #to_h and
# Hash[] built theirs by structure, where two objects are two keys.
#
# ActiveRecord's preloader runs `loaders.group_by(&:loader_query)`: a
# LoaderQuery defines #hash and #eql? so that the same query asked for by
# several associations is sent once. Each loader was a group of its own, and
# 13 tests counted one SELECT too many.
class Q
  attr_reader :k
  def initialize(k) = @k = k
  def hash = @k.hash
  def eql?(o) = o.is_a?(Q) && @k == o.k
  def inspect = "Q(#{@k})"
end
xs = [Q.new(1), Q.new(2), Q.new(1), Q.new(1)]

g = xs.group_by(&:itself)
p g.size, g.values.map(&:size), g.keys, g[Q.new(1)].size
g = xs.group_by { |x| x }
p g.size, g.values.map(&:size)
# the key the block answers, not the element
g = [1, 2, 3, 4].group_by { |i| Q.new(i % 2) }
p g, g[Q.new(0)]
# an Array key holding such objects
g = [1, 2, 3].group_by { |i| [Q.new(i % 2), :x] }
p g.size, g[[Q.new(1), :x]]
# plain keys are as they were, order of first appearance kept
p %w[apple avocado banana blueberry cherry].group_by { |w| w[0] }, [1, 2.0, 1.0, 2].group_by(&:itself)

p xs.zip([:a, :b, :c, :d]).to_h, xs.each_with_index.to_h
p xs.to_h { |x| [x, x.k] }, xs.to_h { |x| [x.k, x] }.size
p Hash[xs.zip([1, 2, 3, 4])], Hash[[[Q.new(5), 1], [Q.new(5), 2]]]
h = xs.zip([:a, :b, :c, :d]).to_h
p h[Q.new(1)], h.key?(Q.new(2)), h.key?(Q.new(3)), h.size
p xs.tally, xs.uniq, xs.each_with_object({}) { |x, acc| acc[x] = 1 }.size

# Array#hash asks a Hash element that holds such a key or value, as
# Hash#hash itself does: `[name, values].hash` is how a LoaderQuery hashes
p [1, { a: Q.new(1) }].hash == [1, { a: Q.new(1) }].hash
p [{ Q.new(1) => 2 }].hash == [{ Q.new(1) => 2 }].hash
p [1, { a: Q.new(1) }].hash == [1, { a: Q.new(2) }].hash
p [1, { a: [Q.new(1)] }].hash == [1, { a: [Q.new(1)] }].hash
p [1, { a: 1 }].hash == [1, { a: 1 }].hash, [{}].hash == [{}].hash
class LQ
  attr_reader :name, :values
  def initialize(name, values) = (@name, @values = name, values)
  def hash = [@name, @values].hash
  def eql?(o) = @name == o.name && @values == o.values
end
class W; attr_reader :v; def initialize(v) = @v = v; def hash = @v.hash; def eql?(o) = v == o.v; def ==(o) = v == o.v; end
a = LQ.new("posts", { where: W.new([1, 2]) })
b = LQ.new("posts", { where: W.new([1, 2]) })
c = LQ.new("posts", { where: W.new([3]) })
p a.hash == b.hash, a.eql?(b), a.hash == c.hash
p [a, b, c].group_by(&:itself).values.map(&:size), [a, b, c].uniq.size
