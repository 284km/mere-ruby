# Ruby 4.0's Binding knows the implicit parameters of the frame it was made
# in -- the numbered ones up to the highest the body names, or `it` -- and
# only that frame's: a parent's and a nested block's do not count.
p proc { _3; binding.implicit_parameters }.call(:a, :b, :c, :d)
p proc { it; binding.implicit_parameters }.call(1)
p proc { binding.implicit_parameters }.call(1)
p proc { |x| binding.implicit_parameters }.call(1)
p proc { _1; proc { binding.implicit_parameters }.call }.call(1)
p proc { f = -> { _1 }; binding.implicit_parameters }.call(1)
p proc { r = binding.implicit_parameter_get(:_2); _2; r }.call(:x, :y)
p proc { it; binding.implicit_parameter_get("it") }.call(:z)
p proc { _2; [1, 2, 3, 4].map { |i| binding.implicit_parameter_defined?(:"_#{i}") } }.call
p proc { it; binding.implicit_parameter_defined?(:_1) }.call(1)
p proc { _2; %i[_1 _2 _3 it].map { |n| binding.implicit_parameter_defined?(n) } }.call
p proc { _1; pr = proc { }; [pr.binding.implicit_parameters, pr.binding.implicit_parameter_get(:_1)] }.call(7)
def err
  yield
rescue NameError, TypeError => e
  [e.class, e.message.sub(/0x\h+/, "XX")]
end
p err { proc { binding.implicit_parameter_get(:_1) }.call }
p err { binding.implicit_parameter_get(:a) }
p err { binding.implicit_parameter_defined?(:_10) }
p err { binding.implicit_parameter_get(1) }

# A copy of a Binding shares the variables it already has and keeps what is
# defined through it afterwards to itself -- in both directions.
def made_here
  a = 1
  binding
end
b1 = made_here
b2 = b1.dup
p b1.equal?(b2), b1 == b2, b1.object_id == b2.object_id
b1.eval("a = 2")
p b2.local_variable_get(:a)
b1.local_variable_set(:x, 37)
b2.eval("y = 1")
p b1.local_variables, b2.local_variables
p b2.local_variable_defined?(:x), b1.local_variable_defined?(:y)
p err { b1.local_variable_set(:$0, 1) }
p err { b1.local_variable_get(:@a) }
p err { b1.local_variable_defined?(:A) }

# ...listed innermost first, and a Binding can be frozen like anything else.
out = 1
p proc { inner = 2; binding.local_variables }.call.first(2)
bf = binding
bf.instance_variable_set(:@iv, 1)
p bf.dup.instance_variables, bf.clone.instance_variable_get(:@iv)
p bf.frozen?, bf.freeze.frozen?, bf.clone.frozen?, bf.dup.frozen?
p((bf.instance_variable_set(:@iv, 2) rescue $!.class))
p(("x".freeze.instance_variable_set(:@a, 1) rescue $!.message))

# Binding#eval takes a file and a line, as Kernel#eval does.
p b1.eval("[__FILE__, __LINE__]", "(named)", 88)
p b1.eval("\n__LINE__", "(named)", 88)
p b1.eval("__FILE__") == "(eval at #{__FILE__}:#{__LINE__})"

# GC.stat answers what this collector keeps: its allocations are real counts.
before = GC.stat(:total_allocated_objects)
strs = Array.new(50) { |i| "s#{i}" }
p GC.stat(:total_allocated_objects) - before >= 50, GC.stat.values.all?(Integer)
