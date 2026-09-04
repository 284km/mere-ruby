# Float#** through libm, and Integer#digits' radix.
#
# `b * pow_flt b (e - 1)` is a linear recursion, so `9.5 ** 0xffffffff` asked
# for 4294967295 nested frames and overflowed the stack -- on an expression
# whose answer is Infinity. Every power now goes through libm's pow, which also
# rounds the way ruby does: the walk gave `2.3 ** 3` as 12.166999999999996
# against ruby's 12.166999999999998.
#
# digits(1) divided by 1 forever, and a negative radix or receiver quietly
# produced a list of negative digits instead of refusing.

p 9.5 ** 0xffffffff
p 2.3 ** 3, 5.2 ** -1, 9.5 ** 0.5, 2.0 ** 10, (-8.0) ** 2, (-2.0) ** 3
p 0.0 ** -1, 2 ** -3, 2 ** 10
p((2**70) ** -1)
p((2**70) ** -2)
p((2**70) ** 0)
p((2**70) ** 2 == 2**140)
# a negative base with a fractional exponent is the principal COMPLEX root.
# The value differs from ruby in the last ulp (cos/sin against ruby's own
# route), so only the shape is compared here.
p(((-8.0) ** Rational(1,3)).class)
p(((-8.0) ** (1.0/3)).class)
p(((-8.0) ** Rational(1,3)).real.round(6))
p(((-8.0) ** Rational(1,3)).imaginary.round(6))

def t
  p yield
rescue => e
  p [e.class, e.message]
end

t { 12345.digits }
t { 12345.digits(7) }
t { 0.digits }
t { 0.digits(7) }
t { 1234.digits(16) }
t { 1234.digits(100) }
t { 980099.digits(100) }
t { 12345.digits(1) }
t { 12345.digits(0) }
t { 12345.digits(-2) }
t { -12345.digits(7) }
t { 12345.digits(nil) }
t { (2**70).digits(10).size }
t { (-(2**70)).digits(10) }

# Math::DomainError is a StandardError, so `rescue => e` catches it. Raising
# the name without registering the class left the program aborting instead.
p Math::DomainError.superclass
p Math::DomainError.ancestors[0, 3]
p((Math::DomainError < StandardError))
