def native_class_argument(first, second)
  first
end

def churn_primitive_class_tables
  2_000.times do
    mixin = Module.new
    Class.new { include mixin }
  end
end

held_mixin = Module.new { def answer; 83; end }
held_class = Class.new { include held_mixin }
held_child = Class.new(held_class)
held_instance = held_child.new
queue = [Class.new { def answer; 84; end }]
churn_primitive_class_tables
native = native_class_argument(queue.pop, GC.start)
raise unless native.new.answer == 84
raise unless held_instance.answer == 83
raise unless held_child.superclass.equal?(held_class)

# The only remaining class value is on a suspended coroutine's native stack.
queue = [Class.new { def answer; 85; end }]
fiber = Fiber.new do
  native_class_argument(queue.pop, Fiber.yield).new.answer
end
fiber.resume
churn_primitive_class_tables
GC.start
raise unless fiber.resume == 85
raise unless held_class.ancestors.include?(held_mixin)
raise unless held_instance.answer == 83
puts 'primitive class table rebuild preserves native and suspended survivors'
