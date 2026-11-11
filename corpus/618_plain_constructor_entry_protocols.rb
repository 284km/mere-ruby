$constructor_entry_events = []
klass = Class.new do
  attr_reader :context
  def initialize
    GC.start
    @context = [__method__, __callee__, caller_locations(0, 3).map(&:base_label)]
    $constructor_entry_events << :initialized
    :ignored
  end
end
object = klass.new
p [object.class.equal?(klass), object.context]
p object.send(:initialize)
p $constructor_entry_events

required = Class.new do
  def initialize(argument)
    @argument = argument
  end
end
begin
  required.new
  raise 'initializer arity was bypassed'
rescue ArgumentError => error
  p error.message
end

changing = Class.new do
  def initialize
    self.class.define_singleton_method(:new) { :replacement }
  end
end
p changing.new.class.equal?(changing)
p changing.new

captured = :captured
defined = Class.new do
  define_method(:initialize) { @value = captured; GC.start }
  attr_reader :value
end
p defined.new.value
$constructor_entry_events = nil
