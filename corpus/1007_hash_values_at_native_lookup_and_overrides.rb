class ConvertedValues1007 < Hash
  alias raw_values_at values_at
  def values_at(*keys)
    keys.map! { |key| key.to_s }
    super
  end
  def [](key)
    raise 'native values_at must not call the override of []'
  end
end
hash = ConvertedValues1007.new
hash.default = nil
hash['name'] = 7
p hash.values_at(:name, :missing)
hash.default = 9
p hash.values_at(:name, :missing)
hash.default_proc = ->(receiver, key) { [receiver.equal?(hash), key] }
p hash.values_at(:name, :missing)
p Hash.instance_method(:values_at).bind(hash).call('name', 'missing')
p hash.raw_values_at('name', 'missing')
identity = {}.compare_by_identity
key = +'same'
identity[key] = :found
p identity.values_at(key, key.dup)
