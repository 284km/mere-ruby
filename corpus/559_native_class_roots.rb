def keep_first(a, b)
  a
end

100.times do
  c = keep_first(Struct.new(:value), GC.start)
  raise "temporary class lost" unless c.new(41).value == 41
end
f = Fiber.new do
  keep_first(Struct.new(:value), Fiber.yield)
end
f.resume
GC.start
c = f.resume
raise "suspended class lost" unless c.new(42).value == 42
m = Class.new { def value; 43; end }.instance_method(:value)
GC.start
raise "method owner lost" unless m.bind_call(m.owner.new) == 43
puts "class roots ok"
