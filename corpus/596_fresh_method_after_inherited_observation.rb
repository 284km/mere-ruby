parent = Class.new do
  def initialize(value = :parent)
    @seen = value
  end
  attr_reader :seen
end
held = nil
before = nil
parent.define_singleton_method(:inherited) do |child|
  held = child.instance_method(:initialize)
  before = held.parameters
  child.ancestors
end
child = Class.new(parent) do
  def initialize(first, second = :child)
    @seen = [first, second]
  end
end
parent.singleton_class.send(:remove_method, :inherited)
p [before, child.instance_method(:initialize).parameters]
instance = child.new(:first, :second)
p instance.seen
GC.start
held.bind_call(instance, :retained)
p instance.seen
p held.source_location == parent.instance_method(:initialize).source_location
