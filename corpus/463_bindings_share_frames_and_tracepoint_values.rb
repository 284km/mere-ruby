# A binding shares its frame: what the frame assigns later is read through it,
# and what it assigns that the frame has is the frame's
proc {
  b = binding
  eval "foo11 = 1", b
  foo22 = 5
  proc { foo22 = 55 }.call
  p eval("foo22", b), eval("foo11", b), b.local_variables.sort & [:b, :foo11, :foo22]
  eval "foo22 = 7", b
  p foo22
  p (defined?(foo11)).inspect
}.call
def mk_binding
  local1 = "local1"
  lambda { local2 = "local2"; return binding }.call
end
x = mk_binding
p eval("local1", x), eval("local2", x)
x = binding
eval "i9 = 1", x
p eval("i9", x), (defined?(i9)).inspect
p [1].each { proc { binding.implicit_parameters } }.size
"foo".tap { p binding.implicit_parameters }

# TracePoint: a define_method body's own break is its value; p's inspect is a
# C method (an Integer's is to_s)
class C463
  define_method(:fb) { break :fb_value }
end
ev = []
TracePoint.new(:b_return, :return) { |t| ev << [t.event, t.method_id, t.return_value] if t.method_id == :fb }.enable { C463.new.fb }
p ev
ids = []
tp = TracePoint.new(:c_call) { |t| ids << t.method_id }
tp.enable { $stdout = File.open(File::NULL, "w"); p 1; $stdout = STDOUT }
p ids.include?(:to_s)

# an alias of a builtin on a String subclass, called with a block
class S463 < String; alias each each_char; end
S463.new("abc").each { |c| print c }
puts
