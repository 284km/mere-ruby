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
