calls = []
h = Hash.new { |hash, key| calls << key; [hash.equal?(h), key] }
50.times { |i| h["k#{i}"] = i }
h["nil"] = nil
h["false"] = false
p [h["k49"], h["nil"], h["false"], h["missing"], calls]
h.delete("k49")
p h["k49"]
h["k49"] = :new
p h["k49"]
h.clear
p h["k1"]

memo = Hash.new { |hash, key| hash[key] = key * 2 }
p [memo[3], memo[3], memo.size]

identity = Hash.new { |_hash, key| [:missing, key] }.compare_by_identity
a = +"same"
b = +"same"
identity[a] = :found
p [identity[a], identity[b]]

class DefaultIndexKey
  def initialize(value)
    @value = value
  end
  attr_reader :value
  def hash
    7
  end
  def eql?(other)
    other.is_a?(DefaultIndexKey) && other.value == value
  end
end
custom = Hash.new { |_hash, key| key.value }
custom[DefaultIndexKey.new(1)] = :found
p [custom[DefaultIndexKey.new(1)], custom[DefaultIndexKey.new(2)]]
GC.start
p [memo[3], identity[a], identity[b]]
