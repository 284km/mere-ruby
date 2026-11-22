# A singleton's undef hides the primitive builtin, as well as Ruby methods.
hash = {}
p [hash.class, hash.respond_to?(:to_hash), {}.respond_to?(:to_hash)]
hash.singleton_class.send(:undef_method, :to_hash)
p [hash.class, hash.respond_to?(:to_hash), hash.respond_to?(:to_hash, true)]
p [hash.singleton_class.method_defined?(:to_hash), {}.respond_to?(:to_hash)]
[:literal, :send, :public_send, :literal_block, :send_block, :public_send_block].each do |kind|
  begin
    case kind
    when :literal then hash.to_hash
    when :send then hash.send(:to_hash)
    when :public_send then hash.public_send(:to_hash)
    when :literal_block then hash.to_hash { :unused }
    when :send_block then hash.send(:to_hash) { :unused }
    when :public_send_block then hash.public_send(:to_hash) { :unused }
    end
  rescue NoMethodError => error
    p [kind, error.name, error.args, error.receiver.equal?(hash), error.private_call?]
  end
end
asked = []
hash.define_singleton_method(:respond_to_missing?) do |name, include_all|
  asked << [name, include_all]
  name == :to_hash
end
hash.define_singleton_method(:method_missing) do |name, *args, &block|
  return super(name, *args, &block) unless name == :to_hash
  [name, args, block && block.call]
end
p [hash.respond_to?(:to_hash), hash.respond_to?(:to_hash, true), asked]
p hash.to_hash
p hash.to_hash(1) { :block }
begin
  hash.missing(2)
rescue NoMethodError => error
  p [error.name, error.args, error.receiver.equal?(hash)]
end
hash.define_singleton_method(:to_hash) { :redefined }
p [hash.to_hash, hash.respond_to?(:to_hash)]

[[[], :to_ary], ['text', :to_str], [proc {}, :call]].each do |object, name|
  object.singleton_class.send(:undef_method, name)
  p [object.class, object.respond_to?(name), object.respond_to?(name, true)]
  begin
    object.public_send(name) { :ignored }
  rescue NoMethodError => error
    p [error.name, error.receiver.equal?(object)]
  end
end

aliased = {}
class << aliased
  alias saved_to_hash to_hash
  undef to_hash
end
p [aliased.saved_to_hash.equal?(aliased), aliased.respond_to?(:saved_to_hash)]

# A Method keeps its definition when undef removes ordinary name lookup.
[[{}, :to_hash, []], [[1, 2], :each, []], ['text', :to_s, []],
 [proc { |value| value * 2 }, :call, [3]]].each do |object, name, arguments|
  captured = object.method(name)
  unbound = captured.unbind
  object.singleton_class.send(:undef_method, name)
  p [object.class, object.respond_to?(name)]
  result = captured.call(*arguments)
  p [result.class, result.equal?(object)]
  p result if name == :call
  if name == :each
    begin
      result.to_a
    rescue NoMethodError => error
      p [error.name, error.receiver.equal?(object)]
    end
    begin
      result.next
    rescue NoMethodError => error
      p [error.name, error.receiver.equal?(object)]
    end
  end
  result = unbound.bind_call(object, *arguments)
  p [result.class, result.equal?(object)]
  p result if name == :call
  result = captured.call(*arguments) { |value| value }
  p [result.class, result.equal?(object)]
  p result if name == :call
  result = unbound.bind_call(object, *arguments) { |value| value }
  p [result.class, result.equal?(object)]
  p result if name == :call
  p captured.call { break :done } if name == :each
end

source = [1]
held = source.method(:each)
source.singleton_class.send(:undef_method, :each)
other = [2]
def other.each
  yield :override
end
seen = []
held.call { other.each { |value| seen << value } }
p seen

hash = {}
held = hash.method(:to_hash)
hash.singleton_class.send(:undef_method, :to_hash)
observer = TracePoint.new(:c_call) { nil }
observer.enable { p held.call { :ignored }.equal?(hash) }

# Coercion methods and string eval also enter Ruby while the builtin runs.
target = +''
held = target.method(:concat)
target.singleton_class.send(:undef_method, :concat)
other = Object.new
def other.concat(value)
  'override'
end
class HeldConversion
  def initialize(other, seen)
    @other, @seen = other, seen
  end
  def to_str
    @seen << @other.concat('x')
    'body'
  end
end
seen = []
held.call(HeldConversion.new(other, seen))
p [target, other.class, seen]

class HeldDefaultConversion < HeldConversion
  def to_str(value = @other.concat('x'))
    @seen << value
    'default body'
  end
end
held.call(HeldDefaultConversion.new(other, seen))
p [target, other.class, seen]

target = +''
held = target.method(:instance_eval)
target.singleton_class.send(:undef_method, :instance_eval)
$held_other = Object.new
def $held_other.instance_eval(*)
  :override
end
p held.call('$held_other.instance_eval("nil")')

# Aliases also retain native definitions, including alias Method objects.
[['ab', :upcase, []], [[1, 2], :each, []],
 [proc { |value| value * 2 }, :call, [3]]].each do |object, original, arguments|
  object.singleton_class.send(:alias_method, :saved_native, original)
  captured = object.method(:saved_native)
  object.singleton_class.send(:undef_method, original)
  p [object.class, object.respond_to?(original), object.respond_to?(:saved_native)]
  result = object.saved_native(*arguments)
  p [result.class, result.equal?(object)]
  p result if original != :each
  seen = []
  result = object.saved_native(*arguments) { |value| seen << value }
  p [result.class, result.equal?(object), seen]
  p result if original != :each
  [:saved_native, :send, :public_send].each do |sender|
    passed = sender == :saved_native ? arguments : [:saved_native, *arguments]
    result = object.public_send(sender, *passed)
    p [result.class, result == object, result] unless original == :each
    p [result.class, result.equal?(object)] if original == :each
    seen = []
    result = object.public_send(sender, *passed) { |value| seen << value }
    p [result.class, result.equal?(object), seen]
    p result if original != :each
  end
  [captured, object.method(:saved_native)].each do |method|
    result = method.call(*arguments)
    p [result.class, result.equal?(object)]
    p result if original != :each
    result = method.call(*arguments) { |value| value }
    p [result.class, result.equal?(object)]
    p result if original != :each
  end
  begin
    object.public_send(original, *arguments) { :ignored }
  rescue NoMethodError => error
    p [error.name, error.receiver.equal?(object)]
  end
end
