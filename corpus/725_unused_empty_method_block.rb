def capture_unused(&block)
end
def capture_used(&block)
  block
end
class EmptyBlockMethods
  def unused(&block)
  end
  def self.unused(&block)
  end
end
target = EmptyBlockMethods.new
def allocated_data(mode, target)
  before = {}; after = {}
  ObjectSpace.count_objects(before)
  GC.start
  GC.disable
  case mode
  when :top then capture_unused {}
  when :instance then target.unused {}
  when :singleton then EmptyBlockMethods.unused {}
  when :used then capture_used {}
  end
  ObjectSpace.count_objects(after)
  after.fetch(:T_DATA, 0) - before.fetch(:T_DATA, 0)
ensure
  GC.enable
end
allocated_data(:none, target) # finish the first-call setup before comparing deltas
p [:unused_top, allocated_data(:top, target)]
p [:unused_instance, allocated_data(:instance, target)]
p [:unused_singleton, allocated_data(:singleton, target)]
p [:used, allocated_data(:used, target)]

observed = []
trace = TracePoint.new(:call) do |event|
  if event.method_id == :capture_unused
    observed << event.binding.local_variable_get(:block).class
  end
end
trace.enable
capture_unused {}
capture_unused
trace.disable
p [:trace_binding, observed]

def default_observes_block(value = binding.local_variable_get(:block), &block)
  value.class
end
def body_observes_block(&block)
  binding.local_variable_get(:block).class
end
def observes_presence(&block)
  block_given?
end
p [:default, default_observes_block {}]
p [:binding, body_observes_block {}]
p [:presence, observes_presence {}, observes_presence]
original = -> { :original }
p [:identity, capture_used(&original).equal?(original), capture_used(&original).lambda?]

# Argument coercion can arm an observer even when none was active at entry.
$observed_conversion_block = []
$conversion_trace = TracePoint.new(:call, :return) do |event|
  if event.method_id == :empty_destructure
    $observed_conversion_block << [event.event, event.binding.local_variable_get(:block).class]
  end
end
def empty_destructure((first, second), &block)
end
class DestructureBlockObserver
  def to_ary
    $conversion_trace.enable
    [1, 2]
  end
end
empty_destructure(DestructureBlockObserver.new) {}
$conversion_trace.disable
p [:conversion_observer, $observed_conversion_block]
