# Keep sparse strings, including empty strings, while many temporary strings
# become unreachable. Collection must preserve aliases, encodings and captures.
kept = []
6.times do |round|
  12000.times do |i|
    value = "#{round}:#{i}"
    kept << [value, value.dup, ''.encode(Encoding::UTF_16LE)] if i % 6000 == 0
  end
  GC.start
end
p kept.map { |a, b, empty| [a == b, empty.empty?, empty.encoding] }.uniq
kept.each { |a, b, empty| a << '!'; empty << 'x'.encode(Encoding::UTF_16LE) }
GC.start
p kept.all? { |a, b, empty| a == b + '!' && empty.encode('UTF-8') == 'x' }
p kept.first[1], kept.last[1]

fiber = Fiber.new do
  local = 'fiber'.dup
  empty = +''
  Fiber.yield [local, empty]
  GC.start
  [local, empty]
end
aliases = fiber.resume
captured = -> { aliases }
3.times do
  10000.times { |i| i.to_s * 2 }
  GC.start
end
aliases[0] << '!'
aliases[1] << 'retained'
p fiber.resume == captured.call
p captured.call

# The enclosing expression spans allocations from an earlier call, including
# strings already collected by that call. Old survivors and fresh strings
# must both remain usable when the next call collects.
def discard_string_handles
  20000.times { |i| i.to_s + 'discarded' }
  GC.start
  nil
end

def retain_string_handles(old)
  fresh = ['fresh'.dup, ''.encode(Encoding::UTF_32BE)]
  GC.start
  old[0] << '?'
  fresh[1] << 'y'.encode(Encoding::UTF_32BE)
  GC.start
  [old[0], fresh[0], fresh[1].encode('UTF-8')]
end
p [discard_string_handles, retain_string_handles(aliases)]
