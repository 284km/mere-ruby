class SymbolReadHash < Hash
  alias raw_get []
  def []=(key, value); super(key.to_sym, value); end
  def [](key); super(key.to_sym); end
end
class ParentReadHash < SymbolReadHash
  def initialize(parent)
    @parent = parent
    super()
    self.default_proc = ->(hash, key) { @parent.raw_get(key) }
  end
end
parent = SymbolReadHash.new
parent[:one] = :parent
value = ParentReadHash.new(parent)
p [:parent, value[:one], value['one']]
value[:one] = :own
p [:own, value[:one], value['one']]
child = ParentReadHash.new(value)
p [:nested, child['one'], child[:one], child.raw_get(:one)]
value[:one] = nil
p [:nil, child['one'], child[:one], child.raw_get(:one)]
value[:one] = false
p [:false, child['one'], child[:one], child.raw_get(:one)]
class NativeDefaultRead < Hash
  alias raw_get []
  def [](key); super(key); end
  def default(key); [:default, key]; end
end
p NativeDefaultRead.new[:absent]
p NativeDefaultRead.new.raw_get(:absent)
class IdentityDefaultRead < Hash
  def [](key); super(key); end
end
identity = IdentityDefaultRead.new { |hash, key| :missing }.compare_by_identity
first = +'same'
second = +'same'
identity[first] = nil
p [identity[first], identity[second], identity.size]
class NamedDefaultRead < Hash
  alias raw_get []
  def [](key); [:override, key]; end
end
aliased = NamedDefaultRead.new { |hash, key| [:fallback, key] }
p [aliased[:unknown], aliased.raw_get(:unknown)]
[[], [:one, :two]].each do |arguments|
  begin
    aliased.raw_get(*arguments)
  rescue => error
    p [error.class, error.message]
  end
end
