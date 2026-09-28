# Collecting while fibers are suspended. Each fiber below stops in the middle
# of an expression that has already built something -- an array element, an
# argument, the left side of an operator, the array a `map` is filling -- and
# then the main stack makes enough garbage to collect, several times, before
# the fibers resume. What each fiber had built must still be there.
def mk(t) = "fresh-" + t
def two(a, b) = "#{a}|#{b}"
class Box; def initialize(v) = (@v = v); def v = @v; end
fibers = {
  array_lit: Fiber.new { [mk("a"), Fiber.yield(1), mk("b")].join("|") },
  args:      Fiber.new { two(mk("a"), Fiber.yield(1)) },
  interp:    Fiber.new { "#{mk("a")}|#{Fiber.yield(1)}" },
  binop:     Fiber.new { mk("a") + Fiber.yield(1).to_s },
  map_acc:   Fiber.new { [1, 2].map { |i| Fiber.yield(i); mk(i.to_s) }.join("|") },
  hash_lit:  Fiber.new { {a: mk("a"), b: Fiber.yield(1)}.inspect },
  obj:       Fiber.new { [Box.new(mk("o")), Fiber.yield(1)].map { |x| x.is_a?(Box) ? x.v : x }.join("|") },
  arr_obj:   Fiber.new { [[mk("n")], Fiber.yield(1)].inspect },
}
fibers.each_value { |f| f.resume }
fibers[:map_acc].resume(:r)   # now suspended with one result in its accumulator
3.times do
  i = 0
  while i < 20000
    o = Object.new
    s = "q" * 40 + i.to_s
    a = [s, i]
    i += 1
  end
  GC.start
end
fibers.each { |k, f| p [k, f.resume(:x)] }

# Past 1024 live fibers a pass gives back the ones nobody can reach -- in the
# middle of this statement, where the only thing holding the fibers is the
# array `map` is still building.
fs = 1100.times.map { f = Fiber.new { Fiber.yield 1; 2 }; f.resume; f }
p [fs.size, fs.map(&:resume).sum]

# A generator held across a loop of garbage: stepped before, during and after.
gen = Enumerator.new { |y| n = 0; loop { y << "v#{n}"; n += 1 } }
seen = [gen.next]
i = 0
while i < 60000
  s = "x" * 50 + i.to_s
  h = {k: s}
  seen << gen.next if i % 20000 == 0
  i += 1
end
GC.start
seen << gen.next
p seen
