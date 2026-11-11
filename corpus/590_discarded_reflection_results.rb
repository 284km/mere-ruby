target_class = Class.new { def value; :value; end }
target = target_class.new
constructor = Class.new do
  def initialize(receiver)
    receiver.method(:value).unbind
  end
  def discarded(receiver)
    receiver.method(:value).unbind
    :done
  end
end
object = constructor.new(target)
p [object.class == constructor, object.discarded(target)]
p object.send(:initialize, target).bind(target).call
begin
  constructor.new(Object.new)
rescue NameError
  p :missing_still_raises
end

seen = []
proxy = Struct.new(:seen) do
  def unbind
    seen << :unbind
    :ignored
  end
end.new(seen)
custom = Object.new
custom.define_singleton_method(:method) { |name| seen << name; proxy }
constructor.new(custom)
p seen

returns = []
trace = TracePoint.new(:return) do |event|
  returns << event.return_value.class if event.method_id == :initialize && event.defined_class == constructor
end
trace.enable { constructor.new(target) }
p returns

breakable = Class.new do
  def initialize
    yield
  end
end
p(breakable.new { break :break_preserved })

factory = Class.new do
  def initialize(receiver)
    receiver.method(:value).unbind
  end
  def self.new(receiver)
    allocate.send(:initialize, receiver)
  end
end
p factory.new(target).bind(target).call
