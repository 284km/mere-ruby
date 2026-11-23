# GC.stat(:total_allocated_objects) counts what the program allocates: not a
# method frame's argument Array (kept for a bare `super`), not the String a
# `return` through the interpreter's flow made for itself, and not a Hash
# GC.stat built to answer one key (sqlite3's
# test_step_does_not_allocate_when_done measures a C method that allocates
# nothing)
class C
  def i(a) = a
  def self.c(a) = a
  def r(a)
    return a
  end
end
module G; def self.s(a, b) = b; end
o = C.new
def m1(a) = a
def window
  2.times { yield }
  b = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - b
end
window { o.i(1) }
p window { o.i(1) }
p window { C.c(1) }
p window { G.s(1, 2) }
p window { m1(1) }
p window { o.r(1) }
p window { nil }
p window { [1, 2] } >= 1
p window { "x" + "y" } >= 1
p GC.stat(:count).is_a?(Integer), GC.stat[:total_allocated_objects].is_a?(Integer)
begin
  GC.stat(:no_such_key)
rescue ArgumentError => e
  p e.message
end
