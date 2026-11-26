class CopyHash1017 < Hash
  attr_accessor :label
  def dup
    copy = super
    [:dup, copy.class.name, copy.label, copy.keys, copy.frozen?]
  end
  def clone
    copy = super
    [:clone, copy.class.name, copy.label, copy.keys, copy.frozen?]
  end
end
hash = CopyHash1017.new
hash[:one] = 1
hash.label = :marker
p hash.dup
hash.freeze
p hash.clone
class CopyArray1017 < Array
  attr_accessor :label
  def dup
    copy = super
    [:dup, copy.class.name, copy.label, copy.to_a]
  end
end
array = CopyArray1017.new([1, 2])
array.label = :array
p array.dup
class CopyString1017 < String
  attr_accessor :label
  def dup
    copy = super
    [:dup, copy.class.name, copy.label, copy.to_s]
  end
end
string = CopyString1017.new('text')
string.label = :string
p string.dup
class PrivateCopyHash1017 < Hash
  private def dup = :private_copy
end
p PrivateCopyHash1017.new.send(:dup)
