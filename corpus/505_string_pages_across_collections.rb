strings = Array.new(9000) { |i| "value#{i}" }
empty = Array.new(50) { '' }
binary = "a\0\xff".b
held = Fiber.new do
  strings[4096].each_char { |char| Fiber.yield(char) }
  :done
end
first = held.resume
3.times { GC.start }
p strings.each_with_index.all? { |s, i| s == "value#{i}" }
p [empty.all?(&:empty?), binary.bytes]

# Old pages must become eligible for compaction again after a mutation.
strings[0].replace('changed')
strings[4095] << ' appended'
strings[8192].clear
binary << "\x80".b
3.times { GC.start }
p [strings[0], strings[4095], strings[8192], binary.bytes]
rest = ''
while held.alive?
  char = held.resume
  rest << char unless char == :done
end
p first + rest

# Drop the old values and exercise pages reused by fresh allocations.
strings = nil
GC.start
fresh = Array.new(9000) { |i| i.to_s }
GC.start
p fresh.each_with_index.all? { |s, i| s == i.to_s }
