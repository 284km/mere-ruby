# Round 29 of note 545: a compare_by_identity hash is indexed by identity --
# two equal Strings are two keys, an Array key stays found however its
# contents move, an object with a #hash of its own is found as itself -- and
# Ractor._require runs the whole require as the main ractor's.
h = {}.compare_by_identity
a = "x"; b = "x".dup
h[a] = 1; h[b] = 2; h[a] = 3
p h.size, h[a], h[b], h["x".dup]
arr = [1]; h[arr] = :arr; arr << 2
p h[arr], h[[1, 2]]
o = Object.new; def o.hash = 1
h[o] = :o
p h[o]
h[1] = :one; h[:s] = :sym; h[nil] = :n; h[1.5] = :f
p h[1], h[:s], h[nil], h[1.5]
h.delete(a)
p h.key?(a), h.key?(b), h.size
g = {}; 20.times { |i| g["k#{i}"] = i }
g.compare_by_identity
p g["k1"], g.size, g.compare_by_identity?
p h.select { true }.compare_by_identity?, h.reject { false }[b]

# many object keys: the walk this replaced was quadratic
big = {}.compare_by_identity
objs = 20_000.times.map { Object.new }
objs.each_with_index { |x, i| big[x] = i }
p big.size, big[objs[12_345]], objs.all? { |x| big.key?(x) }

Warning[:experimental] = false
p Ractor.new { Ractor._require("set"); Set.new([1, 1]).size }.value
