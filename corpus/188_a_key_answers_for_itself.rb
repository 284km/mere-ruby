# A Hash looks a key up by asking it: #hash puts it in a bucket and #eql?
# settles the bucket. A class that defines both is a key like any other -- and
# the containers that are built on Hash (a Set of Sets) depend on it.

class Version
  attr_reader :n
  def initialize(n); @n = n; end
  def hash; n.hash; end
  def eql?(other); other.is_a?(Version) && other.n == n; end
  def ==(other); eql?(other); end
end

h = { Version.new(1) => :one, Version.new(2) => :two }
p h[Version.new(1)], h[Version.new(2)], h[Version.new(3)]
p h.key?(Version.new(1)), h.has_key?(Version.new(3))
p h.include?(Version.new(2)), h.member?(Version.new(2))
p h.fetch(Version.new(1)), h.fetch(Version.new(9), :none)
p h.size, h.delete(Version.new(1)), h.size, h.delete(Version.new(9))
h[Version.new(2)] = :again
p h.size, h[Version.new(2)]

# ...and the same key object twice is one entry
counted = {}
counted[Version.new(5)] = :a
counted[Version.new(5)] = :b
p counted.size, counted.values

# a Set of Sets: every one of these goes through the Hash the Set is built on
p Set[Set[1, 2]].include?(Set[2, 1])
p Set[Set[1], Set[2]] == Set[Set[2], Set[1]]
p Set[Set[1, 2], Set[3]].map { |s| s.to_a.sort }.sort
p({ Set[1] => :a }[Set[1]])
p Set[1, 2].divide { |x, y| (x - y).abs == 1 } == Set[Set[1, 2]]
p Set["one", "two", "three"].classify { |w| w.length } == { 3 => Set["one", "two"], 5 => Set["three"] }

# containers compare by asking their members, not by identity
p [Version.new(1)] == [Version.new(1)], [Version.new(1)] == [Version.new(2)]
p({ a: Version.new(1) } == { a: Version.new(1) })
p({ a: Version.new(1) } == { a: Version.new(2) })
p [Time.at(1)] == [Time.at(1)], [Set[1]] == [Set[1]]
p [[Version.new(1)]] == [[Version.new(1)]]

# an object with no #== of its own still compares by identity
plain = Object.new
p [plain] == [plain], [Object.new] == [Object.new]
p [1, 2] == [1, 2], [1, 2] == [1, 3], ({ 1 => 2 } == { 1 => 2 })
