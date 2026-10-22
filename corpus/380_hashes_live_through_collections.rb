# Hashes are kept by handle now and a dead one's entry is deleted at the
# sweep: what a program still holds -- a hash in a local, in an array, as a
# key, with a default proc, compared by identity, rehashed -- reads the same
# after any number of collections, and throwaway hashes do not pile up

keep = {a: 1}
list = []
30_000.times do |i|
  {i => i, :tmp => [i]}
  list << {n: i} if i % 10_000 == 0
end
GC.start
p keep, list
keep[:b] = 2
GC.start
p keep, keep.size, keep.key?(:b)

d = Hash.new { |h, k| h[k] = k.to_s * 2 }
d[:x]
20_000.times { |i| {i => i} }
GC.start
p d, d[:y], d.keys

ci = {}.compare_by_identity
s1 = "k"
s2 = "k"
ci[s1] = 1
ci[s2] = 2
GC.start
p ci.size, ci[s1], ci[s2], ci.compare_by_identity?

outer = {{a: 1} => :hash_key, [1, {b: 2}] => :array_key}
20_000.times { {z: 1} }
GC.start
p outer[{a: 1}], outer[[1, {b: 2}]]

k = [1]
rh = {k => :v}
k << 2
rh.rehash
GC.start
p rh[[1, 2]]

big = {}
200.times { |i| big["k#{i}"] = i }
10_000.times { |i| {i => i} }
GC.start
p big.size, big["k0"], big["k199"], big.sum { |_, v| v }

nested = {l1: {l2: {l3: [1, {l4: :deep}]}}}
10_000.times { {} }
GC.start
p nested.dig(:l1, :l2, :l3, 1, :l4)

frozen = {f: 1}.freeze
GC.start
p frozen.frozen?, frozen

objs = (1..5).map { |i| {id: i} }
ids = objs.map(&:object_id)
20_000.times { {t: 1} }
GC.start
p objs.map(&:object_id) == ids, objs.map { _1[:id] }
