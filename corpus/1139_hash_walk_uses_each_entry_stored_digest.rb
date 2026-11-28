# Promote beyond CRuby's small-table hash hints. A mutated identical key
# can retain its eight-bit hint by chance; full stored hashes avoid that
# process-random collision making the corpus oracle intermittent.
def stored_hash1139(key, value)
  result = {0 => nil, 1 => nil, 2 => nil, 3 => nil, 4 => nil,
            5 => nil, 6 => nil, 7 => nil, 8 => nil}
  result[key] = value
  result
end

key = [:before]
source = stored_hash1139(key, :stored)
copy = source.dup
key << :after
p [source[key], copy[key], source.key?(key), copy.key?(key)]
p [source.fetch(key, :missing), copy.fetch(key, :missing)]
source.rehash
p [source[key], copy[key]]
copy.rehash
p [source[key], copy[key]]

key = [:first]
hash = stored_hash1139(key, :before_copy)
key << :second
copy = hash.dup
replacement = {}.replace(hash)
p [hash[key], copy[key], replacement[key]]
key.pop
p [hash[key], copy[key], replacement[key]]

key = [1]
hash = stored_hash1139(key, :old)
key << 2
hash[key] = :new
p [(hash.size - 9), hash[key], hash.values.compact]
hash[key] = :updated
p [hash[key], hash.values.compact]
p hash.delete(key)
p [(hash.size - 9), hash[key], hash.values.compact]
hash.rehash
p [(hash.size - 9), hash[key], hash.values.compact]

key = {part: :before}
hash = stored_hash1139(key, :hash_key)
copy = hash.clone
key[:part] = :after
p [hash[key], copy[key]]
hash.rehash
p [hash[key], copy[key]]

key = [1]
identity = {}.compare_by_identity
identity[key] = :identity
copy = identity.dup
key << 2
p [identity[key], copy[key], identity[[1, 2]], copy[[1, 2]]]

key = [1]
hash = stored_hash1139(key, :live)
100.times { { [1] => :temporary } }
GC.start
key << 2
p [hash[key], hash[[1]], hash[[1, 2]]]
hash.rehash
p [hash[key], hash[[1]], hash[[1, 2]]]
key << 3
p [hash[key], hash[[1, 2]]]

class ProtocolArray1139 < Array
  def hash = 7
end
key = ProtocolArray1139[1]
hash = {key => :protocol}
key << 2
p [hash[key], hash.delete(key), hash.empty?]

# A later key mutation must not undo an overwrite still held in the index.
[:values, :dup, :clone, :replace].each do |settlement|
  key = [1]
  hash = stored_hash1139(key, :old)
  hash[key] = :new
  key << 2
  settled = case settlement
            when :values then hash
            when :dup then hash.dup
            when :clone then hash.clone
            when :replace then {}.replace(hash)
            end
  p [settlement, settled.values.compact, hash.values.compact]
end

mixed = {[] => :mutable}
4000.times { |i| mixed[i] = i }
p [mixed.size, mixed[0], mixed[3999]]

# Two distinct entries can have the same historical digest after mutation.
# Updating one, settling an immutable overwrite, copying, restoring the old
# key and deleting one entry must retain the other entry's own value.
[[], {}].each do |container|
  key = container.is_a?(Array) ? [1] : {part: 1}
  fresh = key.dup
  hash = stored_hash1139(key, :old)
  hash[key] = :updated
  key.is_a?(Array) ? key.push(2) : key.store(:extra, 2)
  hash[fresh] = :fresh
  hash[fresh] = :fresh_updated
  p hash.values.compact
  hash[0] = :immutable_updated
  p hash.values.compact
  p [hash.dup.values.compact, {}.replace(hash).values.compact]
  key.is_a?(Array) ? key.pop : key.delete(:extra)
  p [hash[key], hash.fetch(key), hash.key?(key)]
  p hash.delete(fresh)
  p [hash[key], hash.values.compact]
  hash[key] = :after_delete
  p [hash.size, hash[key], hash.values.compact]
  hash.rehash
  p hash.values.compact
end

key = [1]
grouped = [0, 1, 2].group_by do |item|
  if item == 0
    key
  else
    key << 2 if item == 1
    [1]
  end
end
p grouped.values

# Reordering a Hash key leaves its hash/equality unchanged. Nested Hash
# digests are canonical too, while Array elements retain their own order.
key = {a: 1, b: 2}
other = {b: 2, a: 1}
hash = stored_hash1139(key, :unordered)
p [hash[key], hash[other]]
key.delete(:a)
key[:a] = 1
p [hash[key], hash[other]]
nested = stored_hash1139([key, :tail], :nested)
p [nested[[other, :tail]], nested[[:tail, other]]]

# Empty hashes compare equal across identity modes; numeric values keep eql?.
p stored_hash1139({}, :empty)[{}.compare_by_identity]
p [stored_hash1139({a: 1}, :integer)[{a: 1.0}],
   stored_hash1139({a: 1.0}, :float)[{a: 1.0}]]

# Many overwrites preserve key identity, order, snapshots and collection.
keys = Array.new(64) { |i| [i] }
many = {}
keys.each_with_index { |k, i| many[k] = i }
3.times do |round|
  keys.each_with_index { |k, i| many[k] = [round, i] }
  GC.start
end
p [many.size, many.keys == keys, keys.map { |k| many[k] }, many.dup.values]
strings = Array.new(64) { |i| "mixed-#{i}" }
mixed = {[:mutable] => :initial}
strings.each_with_index { |k, i| mixed[k] = i }
strings.each_with_index { |k, i| mixed[k.dup] = i + 100 }
p [mixed.size, strings.map { |k| mixed[k.dup] }, mixed.values.drop(1)]

# Removing earlier entries must not make later deferred values alias a new
# insertion. A historical digest shared by two entries keeps insertion order.
first = [0]
ordered = stored_hash1139(first, :first)
first << 1
ordered[[0]] = :second
first.pop
ordered[first] = :changed_first
p [ordered[first], ordered.values.compact]
ordered.delete(0)
p [ordered[first], ordered.values.compact]
ordered.delete(first)
ordered[[2]] = :new_after_delete
ordered[[0]] = :changed_second
GC.start
p [ordered[[0]], ordered[[2]], ordered.values.compact, ordered.dup.values.compact]

# Equal content digests do not imply identity-mode Hash key equality.
normal = {a: 1, b: 2}
identity = {b: 2, a: 1}.compare_by_identity
literal = {normal => :normal, identity => :identity}
p [literal.size, literal[normal], literal[identity]]
separate = {}
separate[normal] = :normal
separate[identity] = :identity
p [separate.delete(identity), separate.values]
p [{normal => 1, identity => 2}.delete(normal)]
left_key = +'left'
right_key = +'right'
left = {left_key => 1, right_key => 2}.compare_by_identity
reversed = {right_key => 2, left_key => 1}.compare_by_identity
other_objects = {left_key.dup => 1, right_key.dup => 2}.compare_by_identity
mixed_modes = {left => :left, reversed => :reversed, other_objects => :other}
p [left.eql?(reversed), left.eql?(other_objects), mixed_modes.size,
   mixed_modes[left], mixed_modes[reversed], mixed_modes[other_objects]]
p [mixed_modes.delete(other_objects), mixed_modes.values]
empty_normal = {}
empty_identity = {}.compare_by_identity
empty_keys = {empty_normal => :first, empty_identity => :last}
p [empty_keys.size, empty_keys[empty_normal], empty_keys[empty_identity]]
# Ruby Hash#hash stays content based when the identity mode changes or an
# identity key is replaced by a different object with equal content.
changing = {a: 1, b: 2}
outer = stored_hash1139(changing, :mode_kept)
changing.compare_by_identity
p outer[changing]

# A singleton retains its insertion-time digest across copying and promotion.
# Inspect values while a key is changed, and restore it before keyed reads:
# CRuby's randomized small-table hash hints can otherwise collide by chance.
[:literal, :assignment].each do |construction|
  key = [1]
  hash = construction == :literal ? {key => :first} : {}.tap { |h| h[key] = :first }
  hash[key] = :updated
  key << 2
  copies = [hash.dup, hash.clone, {}.replace(hash)]
  GC.start
  p [construction, hash.values, copies.map(&:values)]
  key.pop
  p [hash[key], copies.map { |copy| copy[key] }]
  hash[:second] = :new
  copies.each { |copy| copy[:second] = :copy }
  key << 3
  p [hash.values, copies.map(&:values)]
  key.pop
  p [hash[key], copies.map { |copy| copy[key] }]
end

key = [1]
hash = {key => :original}
key << 2
hash[[1]] = :later
hash[[1]] = :later_updated
key.pop
p [hash.size, hash[key], hash.dup.values, hash.delete([1]), hash.values]
p [hash[[1]], hash.delete([1]), hash.empty?]
hash[[9]] = :reused
p [hash.size, hash[[9]], hash.dup.values]

key = {a: 1}
hash = {key => :hash_key}
key[:b] = 2
copy = hash.dup
key.delete(:b)
hash[:second] = :extra
copy[:second] = :extra
p [hash[key], copy[key], hash.values, copy.values]
changing_key = +'same'
changing = {changing_key => 1}.compare_by_identity
outer = stored_hash1139(changing, :contents_kept)
changing.delete(changing_key)
changing[changing_key.dup] = 1
p outer[changing]
