# BigDecimal, which ruby ships as a C extension and mere-ruby as Ruby: the
# special values and the modes, the precision of a quotient, rounding,
# printing, conversions, coercion with the other numbers, and the gem's own
# Ruby half (power, sqrt, BigMath, bigdecimal/util) running on top
require "bigdecimal"
require "bigdecimal/util"
require "bigdecimal/math"

def try403
  yield
rescue StandardError => e
  [e.class, e.message]
end

B = method(:BigDecimal)
I = BigDecimal::INFINITY
N = BigDecimal::NAN

# the special values
p B.(1) / 0, B.(0) / 0, B.(-1) / 0, I + -I, B.(0) * I, I / I, B.(1) / I, B.(-1) / I
p N == N, N <=> 1, B.("-0"), B.("-0") + B.("0"), B.("-0") * 1
p try403 { B.(1) % 0 }, try403 { B.(1).div(0) }, try403 { I.to_i }, N.to_f.nan?
p [B.("0").sign, B.("-0").sign, B.("1").sign, N.sign, I.sign]

# quotients and their precision
p B.(1) / 3, B.(2) / 3, B.(1).quo(3, 5), B.(1).div(3, 5), B.(10).div(3)
p B.(-7).divmod(2), B.("7.5") % -2, B.("7.5").remainder(-2)
p B.("1") + Rational(1, 3), B.(1) / B.("0.0003")

# rounding
p B.("1.25").round(1), B.("2.5").round, B.("25").round(-1), B.("-1.25").floor(1), B.("1.2").ceil
p B.("1.27").truncate(1), B.("2.5").round(0, :half_even), B.("2.5").round(0, half: :down)
p B.("-1.25").frac, B.("-1.25").fix, B.("-0").abs
BigDecimal.save_rounding_mode do
  BigDecimal.mode(BigDecimal::ROUND_MODE, :floor)
  p B.(2) / 3, BigDecimal.mode(BigDecimal::ROUND_MODE)
end
p BigDecimal.mode(BigDecimal::ROUND_MODE)

# printing
x = B.("1234567.8912345")
p B.("1234.5678").to_s, B.("1234.5678").to_s("F"), x.to_s("3F"), x.to_s("+3"), B.("0.00012345").to_s("F")
p B.("-0.00012345e-10").inspect, B.(1).to_s.encoding, B.(1).inspect.encoding

# the parts
p [B.("1.5").precision, B.("100").precision, B.("0.001").precision, B.("123.45").scale, B.("0.001").n_significant_digits]
p B.("-123.45").split, [B.("123.45").exponent, B.("0.001").exponent]

# conversions
p [B.(0.1), B.(1.0 / 3, 5), B.(1e20), B.(123.456)], B.(Rational(1, 3), 10)
p try403 { B.(Rational(1, 3)) }, try403 { B.("1x") }, B.("1x", exception: false), try403 { B.(nil) }
p B.("  1_000.5e1 "), B.("#12"), BigDecimal.interpret_loosely("12abc")
p B.("1.25").to_r, B.("1.25").to_f, B.("12.9").to_i, "1.5".to_d, 3.to_d, 0.5.to_d, B.("1.5").to_digits

# coercion with the other numbers
p B.("1").coerce(2), 1 + B.("1.5"), 1.5 + B.("1.5"), B.("1.5") + 1.5
p try403 { B.(1) + nil }, try403 { B.(1) > nil }, B.(1) == nil
p Rational(3, 4).coerce(1.0), Rational(3, 4).coerce(10), try403 { Rational(1, 3).coerce(B.(1)) }

# the gem's Ruby half
p B.(2).sqrt(10), B.("1.1")**2, B.(2).power(10), BigMath.PI(10).round(10)

# exponents beyond the representable
p B.("1E11111111111111111111"), B.("1E-11111111111111111111"), (B.("1E1000000000000000000")**10)

# a value is frozen and has no constructor
p B.(1).frozen?, B.(1).dup.equal?(B.(1).dup), try403 { BigDecimal.new(1) }, try403 { BigDecimal.allocate }
p B.("1.0").hash == B.("1.00").hash, { B.("1.0") => :a }[B.("1")]
p Marshal.load(Marshal.dump(B.("3.14"))), B.("3.14")._dump
