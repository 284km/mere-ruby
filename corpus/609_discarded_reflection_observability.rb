receiver = Class.new { def sample; :sample; end }.new
constructor = Class.new do
  def initialize(receiver)
    receiver.method(:sample).unbind
  end
end
holder = Class.new do
  def discarded(receiver)
    receiver.method(:sample).unbind
    :done
  end
  def returned(receiver)
    receiver.method(:sample).unbind
  end
end.new
p [constructor.new(receiver).class.equal?(constructor), holder.discarded(receiver)]
p holder.returned(receiver).bind_call(receiver)
p constructor.allocate.send(:initialize, receiver).bind_call(receiver)

# Disabled GC makes unreachable reflection objects enumerable. Both objects
# must still be fully materialized on that path.
GC.start
disabled = GC.disable
before_methods = ObjectSpace.each_object(Method).count
before_unbound = ObjectSpace.each_object(UnboundMethod).count
3.times { constructor.new(receiver) }
after_methods = ObjectSpace.each_object(Method).count
after_unbound = ObjectSpace.each_object(UnboundMethod).count
GC.enable unless disabled
p [after_methods - before_methods, after_unbound - before_unbound]

# A return observer must see the actual normal initialize result.
events = []
trace = TracePoint.new(:return) do |event|
  if event.method_id == :initialize && event.defined_class.equal?(constructor)
    events << event.return_value.class
  end
end
trace.enable { constructor.new(receiver) }
p events

# Overrides retain both calls, even though the constructor ignores the value.
$discarded_reflection_events = []
replacement = Class.new do
  def unbind
    $discarded_reflection_events << :unbind
    :replacement
  end
end.new
overridden = Class.new do
  define_method(:method) do |name|
    $discarded_reflection_events << name
    replacement
  end
end.new
constructor.new(overridden)
p $discarded_reflection_events
$discarded_reflection_events = nil

flow = Class.new do
  def initialize
    yield
    :ignored
  end
end
p flow.new { break :escaped }
