plain = proc { binding }
p plain.call(1, 2).implicit_parameters
p plain.call(1, 2).implicit_parameter_defined?(:_1)
numbered = proc { [_1, _3, binding.implicit_parameters] }
p numbered.call(4, 5, 6)
p numbered.call([4, 5, 6])
p numbered.call(4)
p proc { [it, binding.implicit_parameters] }.call([7, 8])
it = :outer
p proc { it }.call(:unused)
p proc { || binding.implicit_parameters }.call(1)
p [1, 2, 3].map { |n| proc { n } }.map(&:call)
p [1, 2].map { value = _1; proc { value } }.map(&:call)
p proc { _2; (eval("_1") rescue $!.class) }.call(8, 9)
p proc { _2; binding.implicit_parameter_get(:_1) }.call(8, 9)
b = proc { _3; binding }.call(1, 2, 3)
GC.start
p [b.implicit_parameters, b.implicit_parameter_get(:_3)]

# Unhandled scanner shapes retain the legacy backing slots.
p [3].map { next _1 * 2 }
p [4].map { break _1 }
p [5].map { "value=#{_1}" }
p [6].map { (_1.._1).to_a }
p [7].map { begin; raise "test"; rescue; _1; end }
p [8].map { case _1; when 8; _1 + 1; end }
