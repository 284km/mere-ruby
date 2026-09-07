# ---- 1. Comparable#clamp checks in an ORDER ------------------------------
# Clamping first answered the BOUND for a reversed pair and reported the
# receiver's comparison failure for `5.clamp("a", 1)` -- two wrong answers out
# of one missing order. min-vs-max is compared before the receiver is.
def try(l)
  p l.call
rescue => e
  puts "#{e.class}: #{e.message}"
end
[-> { 5.clamp(3, 1) }, -> { 5.clamp(1...3) }, -> { 2.clamp(1...3) },
 -> { 5.clamp(3..1) }, -> { 5.clamp("a", 1) }, -> { 5.clamp(1, "a") },
 -> { 5.clamp(1) }, -> { 5.clamp }, -> { 5.clamp(1, 2, 3) }].each { |f| try(f) }
p [5.clamp(1, 3), 5.clamp(1..3), 5.clamp(..3), 5.clamp(7..), 5.clamp(nil..nil),
   2.clamp(1..3), 1.0.clamp(1..), (-1).clamp(0, 9)]

# ...and a user object's clamp took only the two-argument form, so the Range
# form answered the RECEIVER for everything that includes Comparable.
class Deg
  include Comparable
  attr_reader :n
  def initialize(n) = @n = n
  def <=>(o) = n <=> o.n
  def inspect = "Deg(#{n})"
end
p [Deg.new(5).clamp(Deg.new(1)..Deg.new(3)), Deg.new(5).clamp(Deg.new(1), Deg.new(3)),
   Deg.new(2).clamp(Deg.new(1), Deg.new(3)), Deg.new(0).clamp(Deg.new(1)..)]
try -> { Deg.new(5).clamp(Deg.new(3), Deg.new(1)) }
try -> { Deg.new(5).clamp(1) }

# ---- 2. minmax's block is a COMPARATOR ----------------------------------
# min and max already read their block as one; minmax dropped it and answered
# the plain minimum and maximum -- the answer to a question nobody asked.
r = ->(a, b) { b <=> a }
p [[1, 2, 3].minmax(&r), [1, 2, 3].minmax, [].minmax(&r), [7].minmax(&r)]
p [(1..5).minmax(&r), ({ a: 1, b: 2 }).minmax { |x, y| y <=> x }]
p [1, 2, 3].minmax { |a, b| break :stopped }

# ---- 3. min(n) / max(n) convert their argument ---------------------------
# Matching an Integer alone made every other kind of argument look like "no
# argument at all", so `[1, 2].max(1.5)` answered 2 instead of [2] and a
# negative n answered [] instead of raising. Array reads a NIL n as "no
# argument" where Range raises on it.
p [[1, 2].max(1.5), [1, 2].min(1.9), [1, 2].max(nil), [1, 2].min(nil),
   [1, 2].max(0), [3, 1, 2].max(2), [3, 1, 2].min(2), [1].max(9)]
[-> { [3, 1, 2].max(-1) }, -> { [3, 1, 2].min(-1) }, -> { [1, 2].max("x") },
 -> { [1, 2].max(2**70) }, -> { (1..3).max(nil) },
 -> { (1..3).max(2**70) }].each { |f| try(f) }
# an array of objects dropped the n as well, answering ONE object for max(2).
p [[Deg.new(3), Deg.new(1)].max(2), [Deg.new(3), Deg.new(1)].min(1),
   [Deg.new(3), Deg.new(1)].max(2) { |a, b| b <=> a }]

# ---- 4. an Enumerator prints the CALL it was made from ------------------
# Without its own printer an Enumerator fell to the default object one and
# published the ivars this implementation happens to store, address and all:
# `#<Enumerator:0x.. @recv=[1, 2], @meth="each">`.
p [1, 2].each
p [1, 2].each_with_index
p [1, 2].each_slice(2)
p [1, 2].each_with_object([1, { a: 2 }])
p "ab".each_char
p 3.times
p({ a: 1 }.each_pair)
p [1, 2].to_enum(:each, 1, "x")
p [1, 2].each.inspect
p [1, 2].lazy
p [1, 2].lazy.map { |x| x }
p [1, 2].lazy.map { |x| x }.select { |x| x }
p [1, 2].lazy.take(2)
p({ a: 1 }.lazy)
p (1..Float::INFINITY).lazy.map { |x| x }
# #to_s is NOT #inspect here -- it is the default one, address and all.
p [1, 2].each.to_s.start_with?("#<Enumerator:0x")
