# Three small holes that each stopped a whole unittest file: a pipe's stat
# and its birth time (test/unit's leak checker inspects it), a do-block on a
# capitalized call with parentheses (DelegateClass(Array) do ... end), and
# `extend ::M` inside a BasicObject subclass (test_forwardable).

def try408
  yield
rescue NotImplementedError, StandardError => e
  [e.class, e.message]
end

r, w = IO.pipe
st = r.stat
b = try408 { st.birthtime }
# (macOS answers the epoch for a pipe; Linux has no birth time in a stat)
p b.is_a?(Time) ? b.to_i : b
p st.inspect.start_with?("#<File::Stat dev=0x"), st.inspect.include?("0x-")
r.close
w.close

def Wrap408(x)
  yield(x) + 1
end
v = Wrap408(1) do |y|
  y * 10
end
p v
p(Wrap408(2) { |y| y * 100 })

module Mixin408
  def mixed = :mixed
end
class Bare408 < BasicObject
  extend ::Mixin408
  include ::Comparable
end
p Bare408.mixed, Bare408.include?(Comparable)
