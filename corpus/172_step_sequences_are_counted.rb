# Numeric#step without a block is an Enumerator::ArithmeticSequence, and its
# #size is COUNTED rather than walked.
#
# `1.step(to: Float::INFINITY, by: 42).size` used to materialize the sequence
# and allocate until the memory cap killed the process -- the worst possible
# answer to a question whose answer is the single word Infinity. The count now
# follows CRuby's ruby_float_step_size, error term and all, and decides the
# infinite ends before it divides.
#
# A Float receiver had no blockless form at all (it answered nil), the keyword
# spelling of a Float walk went to to_f and came back "not a number", and
# `1.step(10, 2.5)` matched an integer-limit arm that walked with a step of 1,
# silently dropping the Float.

inf = Float::INFINITY

[[1, inf, 42], [1, -inf, -42], [1, inf, -42], [1, -inf, 42],
 [1, inf, inf], [1, -inf, -inf], [1, inf, -inf], [1, 10, inf],
 [1, 10, 2.5], [10, 1, -3], [1, 10, 3], [1, 1, 1], [1, 0, 1],
 [1.0, 10.0, 2.0], [1.0, inf, 2.0], [0.0, 1.0, 0.25]].each do |b, e, s|
  q = b.step(to: e, by: s)
  size = q.size
  last = size == inf ? "n/a" : (q.last.inspect rescue $!.class.to_s)
  puts "#{b} to #{e} by #{s} -> #{q.class} size=#{size.inspect} last=#{last}"
end

# the walk itself, with and without a block, keyword and positional
1.0.step(10.0, 2.0) { |x| print x, " " }; puts
1.0.step(to: 10.0, by: 2.0) { |x| print x, " " }; puts
1.step(10, 2.5) { |x| print x, " " }; puts
p 1.0.step(to: 10.0, by: 2.0).to_a
p 1.step(10, 2.5).to_a
p 1.step(10, 2).to_a
p 1.step(10).to_a
p 1.step(by: 2, to: 9).to_a
p (1..10).step(3).to_a
p 1.0.step(to: 10.0, by: 2.0).first(3)
p 1.0.step(to: 10.0, by: 2.0).map { |x| x * 2 }

# what the sequence remembers about the call that made it
p 1.step(10, 2).inspect, 1.0.step(10.0, 2.0).inspect, 1.step(by: 2, to: 9).inspect
q = 1.step(to: 9, by: 2)
p q.begin, q.end, q.step, q.exclude_end?
p q == 1.step(to: 9, by: 2), q == 1.step(to: 9, by: 3)

# an endless sequence still refuses to name a last element
p 1.step.size
begin
  1.step.last
rescue => e
  p e.class
end
begin
  1.step(to: inf, by: 42).last
rescue => e
  p [e.class, e.message]
end
