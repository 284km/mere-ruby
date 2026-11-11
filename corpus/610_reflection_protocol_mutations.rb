receiver = Class.new { def sample; :sample; end }.new
consumer = Class.new do
  def initialize(receiver)
    receiver.method(:sample).unbind
  end
end
3.times { consumer.new(receiver) }

# Changing inherited builtin visibility after the default path has warmed
# must affect discarded expressions just as it affects observed results.
receiver.class.send(:private, :method)
begin
  consumer.new(receiver)
  raise 'private method was bypassed'
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(receiver)]
end
receiver.class.send(:public, :method)
p consumer.new(receiver).class.equal?(consumer)

Method.send(:protected, :unbind)
begin
  consumer.new(receiver)
  raise 'protected unbind was bypassed'
rescue NoMethodError => error
  p error.name
end
Method.send(:public, :unbind)
p consumer.new(receiver).class.equal?(consumer)

# Late Ruby implementations must execute both observable calls.
$reflection_mutations = []
class Method
  def unbind
    $reflection_mutations << :unbind
    :replacement
  end
end
original_target = receiver.method(:sample)
receiver.define_singleton_method(:method) do |name|
  $reflection_mutations << name
  original_target
end
consumer.new(receiver)
p $reflection_mutations
$reflection_mutations = nil
