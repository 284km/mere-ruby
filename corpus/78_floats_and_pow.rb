# Ruby always shows a fractional part before the exponent: 1.0e-06, never
# 1e-06. sassc's numeric precision constant is written that way.
p 1e-06
p 0.000001
p 1e20
p 1.0e100
p 1e-11
p 1.5e-8
p 100000.0
p 0.1
p 1e16
p 1e15
p 123456789012345678.0
p(1 / (10.0**10 * 10))
p (-1.0e-7)
p 1.0
p 2.5
p 1e-06.to_s
p [1e-06, 2.0].inspect

# A Float exponent makes `**` a Float whatever the base is; an Integer base
# with a negative Integer exponent is a Rational.
p 2 ** 3.0
p 2.0 ** 3.0
p 10.0 ** 0.5
p 2 ** 0.5
p 2.0 ** 3
p 4 ** -1
p 2 ** -3
p 10 ** -2
p((-2) ** -2)
p 2 ** 10
p 2.0 ** -2
