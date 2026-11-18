class StringKeys < Hash
  def [](key)
    super(key.to_s)
  end
  def []=(key, value)
    super(key.to_s, value)
  end
end

hash = StringKeys.new
hash[:setup] = [:existing]
p hash[:setup]

module IndexFallback
  def [](key)
    [:object, key]
  end
end
Object.include IndexFallback
p hash[:setup]
hash[:new] ||= []
hash[:new] << :observer
p [hash[:new], hash.keys]

class WrappedArray < Array
  def [](index)
    super(index)
  end
end
class WrappedString < String
  def [](index)
    super(index)
  end
end
p [WrappedArray.new([10, 20])[1], WrappedString.new('ab')[1]]

module EachFallback
  def each
    yield :wrong_ancestor
  end
end
Object.include EachFallback
class WrappedEach < Array
  def each
    super { |value| yield value * 2 }
  end
end
seen = []
WrappedEach.new([2, 3]).each { |value| seen << value }
p seen

module BeforeHash
  def [](key)
    [:before, super]
  end
end
StringKeys.prepend BeforeHash
p hash[:setup]

module UndefIndexAfterHash
  def [](key)
    :unused
  end
  undef_method :[]
end
Object.include UndefIndexAfterHash
class AnotherHash < Hash
  def [](key)
    super
  end
end
another = AnotherHash.new
another[:value] = 42
p another[:value]
