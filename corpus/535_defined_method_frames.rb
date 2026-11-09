class FrameBase
  def value(x, **kw)
    [x, kw]
  end
end
class FrameChild < FrameBase
  define_method(:value) { |x, **kw| super(x + 1, **kw) }
  define_method(:capture) { |x| proc { x } }
  define_method(:binding_for) { |x| binding }
  define_method(:bounce) do |x|
    raise "stop" if x == 0
    bounce(x - 1)
  end
  define_method(:with_block) { |x, &block| block.call(x) }
end
obj = FrameChild.new
kept = [obj.capture(:first), obj.capture(:second)]
bindings = [obj.binding_for(10), obj.binding_for(20)]
1000.times do |i|
  obj.capture(i)
  obj.value(i, key: i)
  begin
    obj.bounce(3)
  rescue RuntimeError
  end
end
GC.start
p kept.map(&:call)
p bindings.map { |b| b.local_variable_get(:x) }
bindings[0].local_variable_set(:x, 30)
GC.start
p bindings.map { |b| b.local_variable_get(:x) }
p obj.value(4, key: 8)
p obj.with_block(3) { |x| x * 2 }
# Top-level define_method uses the same parent-frame lifetime rules.
Object.send(:define_method, :capture_from_top) { |x| proc { x } }
a = capture_from_top(:saved)
100.times { capture_from_top(:temporary) }
GC.start
p a.call
