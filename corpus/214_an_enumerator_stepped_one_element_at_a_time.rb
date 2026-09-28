# Enumerator#next used to drive the WHOLE source into a buffer on the first
# call: an infinite source never came back, and a stateful one ran ahead of
# the caller (a Lazy evaluated every stage in advance). A source that can run
# a program's code is now stepped on a Fiber, one element per #next; a builtin
# iteration of a finite Array / Hash / String / Range still reads a buffer,
# because it cannot tell the difference and a suspended fiber would hold off
# every collection until it ended.
e = [1, 2, 3].each
p e.next, e.peek, e.next, e.next
begin; e.next; rescue StopIteration => x; p [x.message, x.result]; end
nat = Enumerator.new { |y| n = 0; loop { y << n; n += 1 } }
p nat.next, nat.next, nat.next, nat.peek
e2 = Enumerator.new { |y| r = y.yield 1; p [:got, r]; y.yield 2; :ret }
p e2.next; e2.feed :fed; p e2.next
begin; e2.next; rescue StopIteration => x; p x.result; end
seen = []
lz = (1..Float::INFINITY).lazy.map { |x| seen << x; x * 2 }.select { |x| x % 3 == 0 }
p lz.next, seen
e3 = Enumerator.new { |y| y.yield; y.yield 1, 2 }
p e3.next, e3.next_values rescue p $!
e3.rewind; p e3.next_values, e3.peek_values
bad = Enumerator.new { |y| y << 1; raise "boom" }
p bad.next
begin; bad.next; rescue => x; p x.message; end
p bad.next
e4 = 1.upto(3); p e4.next, e4.next; e4.rewind; p e4.next

# dropping a stepped Enumerator over and over, at the top level, ends: the
# ones nobody can reach are given back, and the ones over builtin sources
# never took a fiber at all
gen = 0
i = 0
while i < 3000
  g = Enumerator.new { |y| y << i; y << :more }
  gen += 1 if g.next == i
  a = [i, i + 1].each
  gen += 1 if a.next == i
  i += 1
end
p gen

# ...and inside ONE statement, where the driver never gets a collection point:
# a stepped generator dropped per iteration (CSV.parse_line's shape) is given
# back once enough of them are live, so this does not run out of threads
kept = Enumerator.new { |y| y << :kept1; y << :kept2 }
p kept.next
p 9000.times.count { |k| Enumerator.new { |y| y << k }.next == k }
p kept.next
