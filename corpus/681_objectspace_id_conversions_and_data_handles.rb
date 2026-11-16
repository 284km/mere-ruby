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

kept = [Object.new, proc { :held }, binding, [], {}, ''.dup]
kept.each do |object|
  raise 'held identity did not round trip' unless ObjectSpace._id2ref(object.object_id).equal?(object)
  [IdArgument, PrivateIdArgument, OneArgumentIdQuery, DynamicIdArgument].each do |klass|
    argument = klass.new(object.object_id)
    raise 'integer conversion lost identity' unless ObjectSpace._id2ref(argument).equal?(object)
    raise 'conversion called more than once' if argument.is_a?(IdArgument) && argument.calls != 1
  end
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
