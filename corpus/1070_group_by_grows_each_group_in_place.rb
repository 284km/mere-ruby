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

# Two Strings are one key only when their encodings are comparable too:
# "ab" in UTF-16LE and "ab".b are two, in a group_by and in a Hash, with the
# index or without it (the index took the bytes alone).
u16 = "ab".force_encoding("UTF-16LE")
bin = "ab".b
p [[], u16, bin].group_by(&:itself).values.map(&:size)
p ([u16, bin] + (1..20).to_a).group_by(&:itself).size
h = { [] => 1 }; h[u16] = 2; h[bin] = 3
p h.size, h[u16], h[bin]
h2 = {}; 20.times { |i| h2[i] = i }; h2[u16] = :u; h2[bin] = :b
p h2.size, h2[u16], h2[bin]
p ["é", "é".b, "é".force_encoding("ISO-8859-1")].group_by(&:itself).values.map(&:size)
p ["ab", "ab".b, "ab".force_encoding("US-ASCII"), "ab".force_encoding("EUC-JP"), ""].group_by(&:itself).values.map(&:size)
h3 = {}; 20.times { |i| h3["k#{i}".encode("UTF-16LE")] = i }
p h3["k3".encode("UTF-16LE")], h3["k3"], h3.size

# group_by finds and stores through the Hash itself, not through a program's
# own Hash#[] / #[]= (ruby's calls rb_hash_aref and rb_hash_aset).
class Hash
  alias_method :__aref_1070, :[]
  alias_method :__aset_1070, :[]=
  def [](k) = raise("user Hash#[]")
  def []=(k, v)
    raise "user Hash#[]="
  end
end
r1 = [[1], [1], [2]].group_by(&:itself)
r2 = (1..6).group_by { |i| K.new(i) }.map { |k, v| [k.v, v] }
r3 = (1..40).group_by { |i| [i % 20] }.size
r4 = (1..40).group_by { |i| i % 20 }.size
class Hash
  alias_method :[], :__aref_1070
  alias_method :[]=, :__aset_1070
end
p r1, r2, r3, r4

# A key's own #hash is asked once a lookup (and once a store), not once per
# key already stored: 200 elements, 100 keys, about 300 calls as ruby makes.

class HK
  attr_reader :v
  @@calls = 0
  def self.calls = @@calls
  def initialize(v) = @v = v
  def hash = (@@calls += 1; @v.hash)
  def eql?(o) = o.is_a?(HK) && o.v == @v
end
g = (0...200).map { |i| HK.new(i % 100) }.group_by(&:itself)
p g.size, g.values.map(&:size).uniq, HK.calls.between?(200, 320)
# a program's Hash#default is asked on a miss
class Hash
  alias_method :__default_1070, :default
  def default(k = nil) = raise("user Hash#default")
end
r = [[[1], [1]], [1, 1], [:a]].map do |xs|
  xs.group_by(&:itself)
rescue => e
  e.message
end
class Hash
  alias_method :default, :__default_1070
end
p r
# ...and an Array it answers is pushed onto, not stored
class Hash
  def default(k = nil) = ($dflt_1070 ||= [])
end
h = [1, 2, 1].group_by(&:itself)
class Hash
  alias_method :default, :__default_1070
end
p h, $dflt_1070
