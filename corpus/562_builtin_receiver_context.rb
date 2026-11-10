outer = Module.new
inner = Class.new
name = Object.new
name.define_singleton_method(:to_str) do
  inner.const_defined?(:Other)
  GC.start
  'MissingBuiltinContext'
end
begin
  outer.const_get(name)
  raise 'constant unexpectedly found'
rescue NameError => error
  raise unless error.receiver.equal?(outer) && error.name == :MissingBuiltinContext
end

coercion = Object.new
coercion.define_singleton_method(:to_str) do
  Fiber.yield :paused
  inner.const_defined?(:Other)
  GC.start
  'MissingAfterFiberSwitch'
end
fiber = Fiber.new do
  begin
    outer.const_get(coercion)
    false
  rescue NameError => error
    error.receiver.equal?(outer) && error.name == :MissingAfterFiberSwitch
  end
end
raise unless fiber.resume == :paused
begin
  inner.const_get(:UnrelatedMissing)
rescue NameError => error
  raise unless error.receiver.equal?(inner)
end
GC.start
raise unless fiber.resume
begin
  Integer('invalid')
rescue ArgumentError => error
  raise unless error.message.include?('Integer')
end
puts 'builtin receiver contexts preserved'
