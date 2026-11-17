require 'objspace'
Warning[:deprecated] = false

class IdArgument
  attr_reader :calls
  def initialize(value)
    @value, @calls = value, 0
  end
  def to_int
    @calls += 1
    @value
  end
end
class PrivateIdArgument < IdArgument
  private :to_int
end
class OneArgumentIdQuery < IdArgument
  def respond_to?(name) = (name == :to_int || super)
end
class DynamicIdArgument
  def initialize(value) = (@value = value)
  def respond_to_missing?(name, private_too = false) = (name == :to_int || super)
  def method_missing(name, *args) = (name == :to_int ? @value : super)
end
class NoIdMethod < IdArgument
  undef_method :method
end
previous_verbose = $VERBOSE
$VERBOSE = nil
class IdReflectionTrap < IdArgument
  def method(*) = raise('conversion used reflection')
  def __send__(*) = raise('conversion used __send__')
  def is_a?(*) = raise('conversion used is_a?')
  def class = raise('conversion used class')
end
$VERBOSE = previous_verbose
class BasicIdArgument < BasicObject
  def initialize(value) = (@value = value)
  def to_int = @value
end
class MissingIdArgument
  attr_reader :calls
  def initialize(value) = (@value, @calls = value, 0)
  def method_missing(name, *args)
    return super unless name == :to_int
    @calls += 1
    @value
  end
end
class BasicMissingIdArgument < BasicObject
  def initialize(value) = (@value = value)
  def method_missing(name, *args) = name == :to_int ? @value : super
end
class CollectingMissingIdArgument < MissingIdArgument
  def method_missing(name, *args)
    return super unless name == :to_int
    GC.start
    super
  end
end
class RefusingMissingIdArgument < MissingIdArgument
  def respond_to?(name, private_too = false) = name == :to_int ? false : super
end
class WrongQueryIdArgument < IdArgument
  def respond_to?(name, private_too, extra) = true
end

no_method = NoIdMethod.new(1)
raise 'conversion requires Kernel#method' unless ObjectSpace._id2ref(no_method) == 0 && no_method.calls == 1
trap = IdReflectionTrap.new(1)
raise 'conversion calls argument reflection' unless ObjectSpace._id2ref(trap) == 0 && trap.calls == 1
raise 'conversion requires Kernel' unless ObjectSpace._id2ref(BasicIdArgument.new(1)) == 0
proxy = MissingIdArgument.new(1)
raise 'checked conversion requires an advertised method' unless ObjectSpace._id2ref(proxy) == 0 && proxy.calls == 1
raise 'BasicObject checked conversion missing' unless ObjectSpace._id2ref(BasicMissingIdArgument.new(1)) == 0
refusing = RefusingMissingIdArgument.new(1)
begin
  ObjectSpace._id2ref(refusing)
  raise 'explicit conversion refusal ignored'
rescue TypeError
  raise 'declined conversion was called' unless refusing.calls == 0
end
begin
  ObjectSpace._id2ref(WrongQueryIdArgument.new(1))
  raise 'invalid query arity accepted'
rescue ArgumentError => error
  raise 'query arity error changed' unless error.message == 'respond_to? must accept 1 or 2 arguments (requires 3)'
end

kept = [Object.new, proc { :held }, binding, [], {}, ''.dup, IdArgument]
kept.each do |object|
  raise 'held identity did not round trip' unless ObjectSpace._id2ref(object.object_id).equal?(object)
  [IdArgument, PrivateIdArgument, OneArgumentIdQuery, DynamicIdArgument, MissingIdArgument, BasicMissingIdArgument, CollectingMissingIdArgument].each do |klass|
    argument = klass.new(object.object_id)
    raise 'integer conversion lost identity' unless ObjectSpace._id2ref(argument).equal?(object)
    raise 'conversion called more than once' if (IdArgument === argument || MissingIdArgument === argument) && argument.calls != 1
  end
end
begin
  ObjectSpace._id2ref(MissingIdArgument.new(nil))
  raise 'nil from method_missing accepted'
rescue TypeError => error
  raise 'missing conversion nil confused with refusal' unless error.message == "can't convert MissingIdArgument to Integer (MissingIdArgument#to_int gives NilClass)"
end
[nil, 'bad'].each do |bad|
  begin
    ObjectSpace._id2ref(IdArgument.new(bad))
    raise 'invalid conversion accepted'
  rescue TypeError => error
    expected = "can't convert IdArgument to Integer (IdArgument#to_int gives #{bad.class})"
    raise 'conversion error changed' unless error.message == expected
  end
end
raise 'Float to_int conversion missing' unless ObjectSpace._id2ref(0.0).equal?(false)
GC.start
kept.each do |object|
  raise 'held handle lost after collection' unless ObjectSpace._id2ref(object.object_id).equal?(object)
end
puts 'ObjectSpace id conversion preserves real Proc and Binding identities'
