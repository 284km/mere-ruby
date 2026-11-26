# Enumerable#group_by is ruby's loop: `h[k]`, then `h[k] = [x]` for a new key
# or a push onto the group that is there. Each group grows in place, so 2,000
# elements under one key, or 2,000 keys, cost what 2,000 pushes do (it was a
# new array per element, and a new pair list per key: n^2 bytes both ways).
one = (1..2000).group_by { :all }
p one.size, one[:all].size, one[:all].first(3), one[:all].last
many = (1..2000).group_by(&:itself)
p many.size, many[1], many[2000], many.keys.last(2)
mixed = (1..10).group_by { |i| i % 3 }
p mixed

# A String key is stored as a frozen copy, as Hash#[]= stores one.
words = %w[x y x z].map(&:dup)
g = words.group_by { |s| s.dup }
p g, g.keys.map(&:frozen?), g.keys.first.equal?(words[0])

# A key with its own #hash / #eql? is grouped by them.
K = Struct.new(:v) do
  def hash = v % 2
  def eql?(o) = o.is_a?(K) && v % 2 == o.v % 2
end
p [1, 2, 3, 4].group_by { |i| K.new(i) }.map { |k, v| [k.v, v] }

# 1, 1.0 and 1r are three keys (eql?, not ==).
p [1.0, 1, 1r].group_by(&:itself)

# The groups are the program's to change.
p [3, 1, 2].group_by { |x| x > 1 }.values.map(&:frozen?)

# `break` in the block answers its value.
p([1, 2, 3, 4].group_by { |x| break :stop if x == 3; x.odd? })

# Without a block: an Enumerator, and each gives the same answer.
e = [1, 2, 3].group_by
p e.class, e.each { |x| x.odd? }
