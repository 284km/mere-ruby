# The plain Module allocator keeps the observable constructor protocols.
a = Module.new
b = Module.new
p [a.class, a.equal?(b), a.name]
set_trace_func(proc {})
p Module.new.class
set_trace_func(nil)
TracePoint.new(:line) {}.enable { p Module.new.class }

Module.singleton_class.send(:private, :new)
begin
  Module.new
rescue NoMethodError
  p :private_constructor
end
p Module.send(:new).class
Module.singleton_class.send(:public, :new)

p Module.new(**{}).class
$calls_570 = []
class << Module
  def new(*arguments, &block)
    $calls_570 << :override
    [:factory, arguments, !block.nil?]
  end
end
p Module.new
p Module.new(7) { :unused }
p $calls_570
Module.singleton_class.send(:remove_method, :new)
p Module.new.class
