class KeysMapping941
  attr_reader :calls
  def initialize(result)
    @result = result
    @calls = 0
  end
  def to_hash
    @calls += 1
    @result
  end
end
class PrivateKeysMapping941 < KeysMapping941
  private :to_hash
end
class KeysThroughSuper941 < Hash
  alias_method :saved_keys, :transform_keys
  alias_method :saved_keys!, :transform_keys!
  def transform_keys(*args, &block) = super
  def transform_keys!(*args, &block) = super
end

[Hash, KeysThroughSuper941].each do |type|
  [:transform_keys, :transform_keys!].each do |operation|
    [nil, false, 1, 'bad'].each do |argument|
      [false, true].each do |frozen|
        hash = type[a: 1, b: 2]
        hash.freeze if frozen
        begin
          hash.public_send(operation, argument)
        rescue TypeError => error
          p [type.name, operation, frozen, error.class, error.message]
        end
      end
    end
    [KeysMapping941, PrivateKeysMapping941].each do |mapping_type|
      mapping = mapping_type.new(a: :A)
      hash = type[a: 1, b: 2]
      p [type.name, operation, hash.public_send(operation, mapping), mapping.calls]
      mapping = mapping_type.new(a: :A)
      hash = type[a: 1, b: 2]
      p [type.name, operation, hash.public_send(operation, mapping) { |key| key.to_s }, mapping.calls]
    end
    [nil, 1].each do |bad_return|
      begin
        type[a: 1].public_send(operation, KeysMapping941.new(bad_return))
      rescue TypeError => error
        p [error.class, error.message]
      end
    end
    begin
      type[a: 1].public_send(operation, {}, {})
    rescue ArgumentError => error
      p [error.class, error.message]
    end
  end
end

hash = KeysThroughSuper941[a: 1, b: 2]
p hash.saved_keys(KeysMapping941.new(a: :A))
p hash.saved_keys!(KeysMapping941.new(b: :B))
p({a: 1}.freeze.transform_keys!().class)

# A Ruby override keeps control of its own arguments, even when frozen.
class CustomKeys941 < Hash
  def transform_keys!(_argument) = :custom
end
p CustomKeys941.new.freeze.transform_keys!(nil)

# Coercion precedes the native iterator guard and its frozen check.
class MutatingKeysMapping941
  attr_reader :calls
  def initialize(hash, freeze_target)
    @hash, @freeze_target, @calls = hash, freeze_target, 0
  end
  def to_hash
    @calls += 1
    @hash[:added] = 3
    @hash.freeze if @freeze_target
    {a: :A, added: :ADDED}
  end
end
[Hash, KeysThroughSuper941].each do |type|
  [:transform_keys, :transform_keys!].each do |operation|
    [false, true].each do |freeze_target|
      [false, true].each do |with_block|
        hash = type[a: 1, b: 2]
        mapping = MutatingKeysMapping941.new(hash, freeze_target)
        begin
          result = if with_block
            hash.public_send(operation, mapping) { |key| key.to_s }
          else
            hash.public_send(operation, mapping)
          end
          p [type.name, operation, freeze_target, with_block, result, hash, mapping.calls]
        rescue FrozenError => error
          p [type.name, operation, freeze_target, with_block, error.class, hash, mapping.calls]
        end
      end
    end
  end
end
class NilKeysMapping941
  def respond_to_missing?(name, priv=false) = name == :to_hash || super
  def method_missing(name, *args)
    return nil if name == :to_hash
    super
  end
end
class DeniedKeysMapping941
  def respond_to?(name, *args) = name == :to_hash ? false : super
  def to_hash = nil
end
s = +''
def s.to_hash = {a: :A}
[NilKeysMapping941.new, DeniedKeysMapping941.new, s].each do |mapping|
  begin
    p({a: 1}.transform_keys(mapping))
  rescue TypeError => e
    p [e.class, e.message]
  end
end

# Array subclass overrides also receive keys before native index coercion.
class KeyedArray941 < Array
  attr_reader :writes
  def []=(key, value)
    @writes ||= []
    @writes.replace([key, value])
    :writer_return
  end
  def [](key) = [:read, key]
  def fetch(key) = [:fetch, key]
end
keyed941 = KeyedArray941.new
p [:assignment, (keyed941['file.txt'] = 'body'), keyed941.writes]
p [:read, keyed941['file.txt'], keyed941.fetch('file.txt')]
native_write941 = Array.instance_method(:[]=).bind(keyed941)
index941 = Object.new
def index941.to_int = 0
p [:native_write, native_write941.call(index941, 7), Array.instance_method(:[]).bind_call(keyed941, 0)]
keyed941.freeze
p [:frozen_override, (keyed941['other'] = 8)]
class ForwardIndexArray941 < Array
  def []=(*args)
    super
  end
  def [](*args)
    super
  end
end
forward941 = ForwardIndexArray941.new
p [:native_super, (forward941[index941] = 9), forward941[index941]]

# An overriding reader/fetch receives the original object, without to_int.
class OriginalIndex941
  attr_reader :calls
  def initialize = @calls = 0
  def to_int
    @calls += 1
    0
  end
end
class OriginalIndexArray941 < Array
  def [](index) = index
  def fetch(index) = index
  def at(index) = index
  def rotate(index) = index
  def delete_at(index) = index
end
original_index941 = OriginalIndex941.new
original_array941 = OriginalIndexArray941.new
p [:original_index, [:[], :fetch, :at, :rotate, :delete_at].map { |name|
  original_array941.public_send(name, original_index941).equal?(original_index941)
}, original_index941.calls]
singleton_array941 = []
def singleton_array941.[](index) = index
p [:singleton_original_index, singleton_array941[original_index941].equal?(original_index941), original_index941.calls]
