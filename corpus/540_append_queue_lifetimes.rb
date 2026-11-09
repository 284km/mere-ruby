# Values read from an append queue remain valid while the queue is cleared,
# collected, and reused, including across a suspended Fiber.
def retain(first, _)
  first
end

200.times do |round|
  a = []
  a << [round, "array-#{round}"]
  value = retain(a[0], (a.clear; GC.start; 20.times { [] << :reuse }))
  raise "array alias changed" unless value == [round, "array-#{round}"]

  h = {}
  h[:key] = [round, "hash-#{round}"]
  value = retain(h[:key], (h.clear; GC.start; 20.times { {}[:key] = :reuse }))
  raise "hash alias changed" unless value == [round, "hash-#{round}"]
end

a = []
2000.times { |i| a << [i] }
raise "pop order" unless a.pop == [1999]
raise "shift order" unless a.shift == [0]
a << [:last]
raise "queue length" unless a.length == 1999 && a.last == [:last]

h = {}
h[:kept] = ["held", 42]
fiber = Fiber.new do
  retain(h[:kept], Fiber.yield)
end
fiber.resume
h.clear
GC.start
100.times { |i| {}[i] = [i] }
raise "suspended alias changed" unless fiber.resume == ["held", 42]
puts :ok
