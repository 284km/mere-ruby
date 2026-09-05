# Set is core in ruby 4.0, and this is the library mere-ruby ships in its place
# asked the questions core/set asks: what each operation answers, which
# arguments it refuses and how, and what a walk forbids while it is walking.

s = Set["one", "two", "three", "four"]

# classify / divide: a one-argument block groups by its value, a TWO-argument
# one is a relation whose subsets are the graph's strongly connected components
p s.classify { |x| x.length }.keys.sort
p s.divide { |x| x.length }.map { |x| x.to_a.sort }.sort
p Set[1, 3, 4, 6, 9, 10, 11].divide { |x, y| (x - y).abs == 1 }.map { |x| x.to_a.sort }.sort
pairs = []
Set[1, 2].divide { |x, y| pairs << [x, y] }
p pairs.sort
p Set[1, 2, 3].divide { |x, y| x < y }.map { |x| x.to_a.sort }.sort

# flatten refuses a set that contains itself rather than walking forever
p Set[1, 2, Set[3, 4, Set[5]]].flatten
p Set[1, Set[2]].flatten!, Set[1, 2].flatten!
begin
  r = Set[]
  r << r
  r.flatten
rescue ArgumentError => e
  p e.message
end

# the in-place filters answer nil when they removed nothing
t = Set[1, 2, 3]
p t.select! { |x| x > 1 }, t
p Set[1, 2].select! { true }, Set[1, 2].reject! { false }
u = Set[1, 2]
p u.map! { |x| x * 10 }, u.equal?(u.map! { |x| x })
p Set[1, 2, 3].delete_if { |x| x > 2 }, Set[1, 2, 3].keep_if { |x| x > 2 }
p Set[:a].join, Set[:a, :b].join, Set[:a, :b].join(" | "), Set[].join
v = Set[:a, :b, :c]
p v.replace([1, 2]).equal?(v), v
p Set[1, 2, 3].subtract([2]), Set[1, 2] ^ Set[2, 3]
p(Set[] <=> Set[], Set[1, 2] <=> Set[1, 2, 3], Set[1, 2, 3] <=> Set[1, 2])
p(Set[1] <=> Set[:a], Set[1] <=> false)

# a collection argument must be enumerable, and a set argument must be a set:
# two refusals, named differently
[-> { Set[1] | 1 }, -> { Set[1] & 1 }, -> { Set[1] - 1 }, -> { Set[1] ^ 1 },
 -> { Set[1].merge(1) }, -> { Set.new(1) }, -> { Set[1].disjoint?(1) },
 -> { Set[1].subset?(1) }, -> { Set[1].superset?([1]) },
 -> { Set[1].proper_subset?(1) }, -> { Set[1].proper_superset?(1) }].each do |f|
  begin
    f.call
  rescue ArgumentError => e
    puts e.message
  end
end

# a frozen set refuses every mutation, by that name
frozen = Set[1].freeze
[[:add, [1]], [:delete, [1]], [:clear, []], [:merge, [[1]]],
 [:replace, [[1]]], [:subtract, [[1]]], [:map!, []]].each do |m, args|
  begin
    frozen.send(m, *args) { |x| x }
  rescue FrozenError => e
    puts m.to_s + ": " + e.message
  end
end
p frozen.to_a, frozen.frozen?, frozen.inspect

# ...but a frozen set still walks, and so does a plain one that is being walked:
# adding a NEW item, merging and replacing are the three ruby refuses
seen = []
frozen.each { |x| seen << x }
p seen
w = Set[:a, :b]
begin
  w.each { w << :c }
rescue RuntimeError => e
  p e.message
end
begin
  w.each { w.merge([:a]) }
rescue RuntimeError => e
  p e.message
end
begin
  w.each { w.replace([1]) }
rescue RuntimeError => e
  p e.message
end
w.each { w.add(:a) }            # already a member: allowed
w.each { w.delete(:b) }         # deleting is allowed
p w
w << :c                         # ...and the walk is over
p w.include?(:c)

# comparison by identity is a property of the set, and it survives a dup
a = "x"
byid = Set.new.compare_by_identity
byid.merge([a, a.dup])
p byid.size, byid.compare_by_identity?, byid.dup.compare_by_identity?
p Set.new([1, 2]) == Set.new([1, 2]).compare_by_identity
p Set.new([1, 2]) == Set.new([2, 1])

# a subclass keeps the older inspect, and to_set answers self only for a Set
class Multiset < Set; end
p Multiset[1, 2], Multiset.new, Multiset[1].dup.class
one = Set[1]
p one.to_set.equal?(one), one.to_set(Multiset).class
p Set[1].eql?(Set[1]), Set.instance_method(:eql?) == Set.instance_method(:==)
