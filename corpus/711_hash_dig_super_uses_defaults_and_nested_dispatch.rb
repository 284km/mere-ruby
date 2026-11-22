class DigSuperHash < Hash
  def dig(*keys)
    super
  end

  def [](key)
    raise 'native dig must not dispatch the first [] override'
  end
end

h = DigSuperHash.new
h[:nil] = nil
h[:array] = [{leaf: :value}]
h[:scalar] = 'text'
p h.dig(:nil, :anything)
p h.dig(:array, 0, :leaf)
p h.dig(:missing, 0)
begin
  h.dig
rescue ArgumentError => error
  p [error.class, error.message]
end
begin
  h.dig(:scalar, :nested)
rescue TypeError => error
  p [error.class, error.message]
end

class NestedDigTarget
  def dig(*keys)
    [:nested, keys]
  end
end
h[:custom] = NestedDigTarget.new
p h.dig(:custom, :one, two: 2)
h.default = NestedDigTarget.new
p h.dig(:missing, :default)
h.default_proc = proc { |hash, key| [hash.equal?(h), key] }
p h.dig(:missing)

class DigDefaultHash < DigSuperHash
  def default(key)
    {key => :default_override}
  end
end
p DigDefaultHash.new.dig(:key, :key)

module PrependDig
  def dig(*keys)
    [:outer, super]
  end
end
DigSuperHash.prepend(PrependDig)
p h.dig(:array, 0, :leaf)

class NestedDigHash < Hash
  def dig(*keys)
    [:nested_hash, keys]
  end
end
h[:nested_hash] = NestedDigHash.new
p h.dig(:nested_hash, :left)
