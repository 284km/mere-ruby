# This case observes uncollected objects, so disable forced stress as well.
GC.stress = false
target = Class.new { def value; :ok; end }.new
$disabled_gc_target = target
factory = Class.new do
  def initialize
    object = $disabled_gc_target
    object.method(:value).unbind
  end
end
GC.start
GC.disable
before = ObjectSpace.each_object(Method).count
3.times { target.method(:value).unbind }
3.times { factory.new }
after = ObjectSpace.each_object(Method).count
p after - before >= 6
GC.enable
p target.method(:value).unbind.bind(target).call
