# defined?(A::B) whose head A is not there answers nil and makes nothing on
# the way. (A bare head evaluated to see what it names raised a NameError,
# backtrace and all, inside defined? -- Ractor.make_shareable's
# `defined?(Psych::Parser)` without Psych, once per constant of a
# `shareable_constant_value: literal` body: 72 objects for 10 of them, and
# test_gc's test_ast_node_buffer 4-5x slower.)
def probe = defined?(NopeHeadZ::X)
p probe
p defined?(NopeHeadZ::X::Y)
p defined?(Comparable::Nope)
p defined?(Comparable)
p $!
probe
GC.disable
t0 = GC.stat(:total_allocated_objects)
10.times { probe }
p GC.stat(:total_allocated_objects) - t0 < 10
GC.enable
# (a head that IS there through the nesting is still asked: the case the
# evaluation was added for)
class Box912; end
module Outer912
  p defined?(Box912::Inner)
  class Box912; Inner = 1; end
  p defined?(Box912::Inner)
end
# (and a shareable-literal body defines its constants as before)
m = Module.new
m.class_eval("# shareable_constant_value: literal\nA = {}\nB = [1]\n")
p [m::A.frozen?, m::B]
