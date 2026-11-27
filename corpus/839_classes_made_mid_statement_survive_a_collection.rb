# A class made in the middle of a statement, held only by the statement's
# half-evaluated arguments, survives a collection there: an argument, an
# element of an Array literal, the receiver of a call not yet made -- in a
# method, in a block, and on a Fiber suspended in that statement. (Kept by
# the class watermark, not by the scan of the stack for class names:
# tools/class_watermark_check.sh runs this with the scan left out.)
def first_of(a, b) = a
def make_and_collect = first_of(Class.new { def v = 1 }, GC.start)

p first_of(Class.new { def v = 2 }, GC.start).new.v
p first_of(Module.new { def self.v = 3 }, GC.start).v
p first_of(Struct.new(:a), GC.start).new(4).a
p first_of(Data.define(:b), GC.start).new(b: 5).b
p [Class.new { def v = 6 }, GC.start].first.new.v
p make_and_collect.new.v
p (1..2).map { |i| first_of(Class.new { define_method(:v) { i * 10 } }, GC.start).new.v }
p first_of(Class.new(first_of(Class.new { def w = 7 }, GC.start)) { def v = w + 1 }, GC.start).new.v

f = Fiber.new do
  first_of(Class.new { def v = 9 }, Fiber.yield)
end
f.resume
3.times { GC.start }
p f.resume.new.v
