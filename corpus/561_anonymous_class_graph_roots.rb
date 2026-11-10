def first_class(first, second)
  first
end
raise unless first_class(Class.new { def answer; 42; end }, GC.start).new.answer == 42

instance = Class.new { def answer; 43; end }.new
array = Class.new(Array) { def answer; 44; end }.new
method = Class.new { def answer; 45; end }.new.method(:answer)
unbound = Class.new { def answer; 46; end }.instance_method(:answer)
owner = unbound.owner
klass = Class.new
klass.const_set(:Child, Class.new { def answer; 47; end })
klass.instance_variable_set(:@state, [48])
klass.class_variable_set(:@@state, [49])
mod = Module.new
mod.const_set(:State, [50])
mod.module_eval { define_method(:state) { mod.const_get(:State) } }
klass.include(mod)
obj = klass.new
fiber_class = Class.new
fiber_class.const_set(:Worker, Fiber.new { Fiber.yield :paused; 51 })
raise unless fiber_class::Worker.resume == :paused

refined_target = Class.new { def answer; 0; end }
refinery = Module.new do
  refine refined_target do
    def answer; 52; end
  end
end
refined_host = Class.new do
  using refinery
  define_method(:answer) { refined_target.new.answer }
end
module ClassGcRefinementNamespace
  module Refinery
    refine String do
      def class_gc_witness; 53; end
    end
  end
end
named_refined_host = Class.new do
  using ClassGcRefinementNamespace::Refinery
  def answer; ''.class_gc_witness; end
end

# The only remaining path to this class is a suspended native stack.
fiber = Fiber.new do
  local = Class.new { def answer; 54; end }
  Fiber.yield :ready
  local.new.answer
end
raise unless fiber.resume == :ready
4.times { GC.start }
raise unless instance.answer == 43 && array.answer == 44
raise unless method.call == 45 && unbound.bind(owner.new).call == 46
raise unless klass::Child.new.answer == 47
raise unless klass.instance_variable_get(:@state) == [48]
raise unless klass.class_variable_get(:@@state) == [49]
raise unless obj.state == [50]
raise unless fiber_class::Worker.resume == 51
raise unless refined_host.new.answer == 52 && named_refined_host.new.answer == 53
raise unless fiber.resume == 54
ids = []
100.times do
  ids << Class.new.object_id
  GC.start
end
raise unless ids.uniq.length == ids.length
puts 'anonymous class graph roots preserved'
namespace = Module.new
namespace.module_eval('class Nested; def answer; 55; end; end')
nested_instance = namespace.const_get(:Nested).new
namespace = nil
GC.start
raise unless nested_instance.answer == 55
captured = nil
Module.new do
  refine String do
    def retained_class_gc_witness; 56; end
    captured = proc { ''.retained_class_gc_witness }
  end
end
GC.start
raise unless captured.call == 56
escaped = nil
begin
  Module.new do
    refine String do
      def escaped_class_gc_witness; 57; end
      escaped = proc { ''.escaped_class_gc_witness }
      raise 'leave refinement'
    end
  end
rescue RuntimeError => error
  raise unless error.message == 'leave refinement'
end
GC.start
raise unless escaped.call == 57
exception = Class.new(StandardError) { def answer; 58; end }.new('message')
regexp = Class.new(Regexp) { def answer; 59; end }.new('class-gc')
GC.start
raise unless exception.answer == 58 && regexp.answer == 59
raise unless exception.message == 'message' && regexp.match?('class-gc')
namespace = Module.new
namespace.module_eval('module Refinery; refine String do; def anonymous_namespace_gc_witness; 60; end; end; end')
refiner = namespace.const_get(:Refinery)
host = Class.new do
  using refiner
  def answer; ''.anonymous_namespace_gc_witness; end
end
namespace = refiner = nil
GC.start
raise unless host.new.answer == 60
owner = Class.new
singleton = owner.singleton_class
singleton.class_eval('class Nested; def answer; 61; end; end')
child = singleton.const_get(:Nested)
child.const_set(:Marker, [61])
owner = singleton = nil
GC.start
raise unless child.instance_methods(false).include?(:answer) && child.const_get(:Marker) == [61]

# Fetching a Regexp from a container removes constructor temporaries as roots.
regex_store = [Class.new(Regexp) { def answer; 73; end }.new('popped-native-pattern')]
GC.start
native_regex = first_class(regex_store.pop, GC.start)
raise unless native_regex.answer == 73
regex_store = [Class.new(Regexp) { def answer; 74; end }.new('popped-suspended-pattern')]
GC.start
regex_fiber = Fiber.new do
  saved_regex = first_class(regex_store.pop, Fiber.yield)
  raise unless saved_regex.answer == 74
end
regex_fiber.resume
GC.start
regex_fiber.resume
