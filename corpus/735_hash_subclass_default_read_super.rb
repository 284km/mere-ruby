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

class NativeReadHash < Hash
  alias raw_get []
end
class NativeReadKey
  attr_reader :calls
  def initialize(code = 1); @code = code; @calls = 0; end
  def hash
    @calls += 1
    raise 'hash called twice' if @armed && @calls > 1
    @nested.call if @nested
    @code
  end
  def arm(nested = nil); @calls = 0; @armed = true; @nested = nested; end
  def change(code); @code = code; end
end
key = NativeReadKey.new
native_read = NativeReadHash.new
native_read[key] = :stored
key.arm
p [:native_hash_calls, native_read.raw_get(key), key.calls]
missing = NativeReadKey.new
missing.arm
p [:native_missing_calls, native_read.raw_get(missing), missing.calls]
empty_key = NativeReadKey.new
empty_key.arm
p [:native_empty_calls, NativeReadHash.new.raw_get(empty_key), empty_key.calls]
identity_key = NativeReadKey.new
identity_read = NativeReadHash.new.compare_by_identity
identity_read[identity_key] = :identity
identity_key.arm
p [:native_identity_calls, identity_read.raw_get(identity_key), identity_key.calls]
inner_key = NativeReadKey.new
inner_read = NativeReadHash.new
inner_read[inner_key] = :inner
inner_key.arm
key.arm(proc { inner_read.raw_get(inner_key) })
p [:native_nested_calls, native_read.raw_get(key), key.calls, inner_key.calls]
key.arm
key.change(2)
p [:native_changed_code, native_read.raw_get(key), key.calls]

colliding = Array.new(3) { NativeReadKey.new }
collision_read = NativeReadHash.new
colliding.each_with_index { |item, index| collision_read[item] = index }
colliding.each(&:arm)
p [:native_collision_calls, collision_read.raw_get(colliding.last), colliding.map(&:calls)]
class NativeSuperReadHash < Hash
  def [](key); super; end
end
super_key = NativeReadKey.new
super_read = NativeSuperReadHash.new
super_read[super_key] = :super
super_key.arm
p [:native_super_calls, super_read[super_key], super_key.calls]
