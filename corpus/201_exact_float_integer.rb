# mere-ruby had no EXACT Float -> Integer conversion, and every question that
# needs one went through a machine int instead: `int_of_float` SATURATES.
#
#   1.0e30.to_i   answered 9223372036854775807  (Int64 max)
#   1.0e30.ceil   answered -9223372036854775808 (Int64 MIN -- the wrong SIGN)
#
# `Integer()` had the exact conversion all along; six other doors did not.
# Above 2**53 a float is already a whole number, so to_i, floor, ceil, round
# and truncate all answer the same exact integer.

def t(label)
  p [label, (yield)]
rescue Exception => e
  p [label, e.class, e.message[0, 44]]
end

t(:to_i)     { 1.0e30.to_i }
t(:floor)    { 1.0e30.floor }
t(:ceil)     { 1.0e30.ceil }
t(:round)    { 1.0e30.round }
t(:truncate) { 1.0e30.truncate }
t(:to_r)     { 1.0e30.to_r }
t(:rational) { 1.0e30.rationalize }
t(:integer)  { Integer(1.0e30) }
t(:negative) { (-1.0e30).to_i }
t(:pow2)     { (2.0**80).ceil }
t(:divmod)   { 1.0e30.divmod(7) }
t(:div)      { 9223372036854775808.div(1.0) }

# Integer <=> Float compares EXACT values. Converting the integer to a double
# rounds it: 4611686018427387903.0 is really 2**62, so the integer is smaller.
big = 4611686018427387903
t(:cmp)  { big <=> big.to_f }
t(:lt)   { big < big.to_f }
t(:lte)  { big <= big.to_f }
t(:eq)   { big == big.to_f }
t(:eq_r) { big.to_f == big }

# The machine-int range is NOT symmetric, and testing the magnitude alone left
# Int64 MIN as a bignum when arithmetic reached it -- so one value had two
# representations and `==`, `eql?` and `hash` all disagreed with themselves.
a = (-4611686018427387904) >> -1
b = -4611686018427387904 * 2
t(:same) { [a, b, a == b, a.eql?(b), a.hash == b.hash, a.class] }

# A NEGATIVE precision rounds to that power of ten; `d <= 0` dropped it.
t(:floor_neg) { 12345.678.floor(-2) }
t(:ceil_neg)  { 12345.678.ceil(-2) }
t(:round_neg) { 12345.678.round(-2) }
t(:trunc_neg) { 12345.678.truncate(-2) }
t(:int_trunc) { 12345.truncate(-2) }
t(:int_trunc_neg) { (-12345).truncate(-2) }

# ...and the precision argument is converted with #to_int, so a Float one is
# truncated -- while one too large for a Float to notice changes nothing, and
# an infinite one is a RangeError about the CONVERSION, not a FloatDomainError
# about the receiver.
t(:prec_float) { 12.345678.round(3.999) }
t(:prec_huge)  { 0.42.round(2.0**23) }
t(:prec_big)   { 0.42.round(2**70) }
t(:prec_inf)   { 1.5.round(Float::INFINITY) }
t(:prec_nan)   { 1.5.round(Float::NAN) }

# round is half AWAY FROM ZERO, and `floor(x + 0.5)` is not that: the addition
# itself rounds 0.49999999999999994 up to exactly 1.0.
t(:half) { [0.49999999999999994.round, (-0.49999999999999994).round, 2.5.round, (-2.5).round, 0.5.round] }

# a Float or Rational operand next to a BIGNUM had no arm at all
t(:big_mod_f)   { (2**64) % 3.5 }
t(:f_mod_big)   { 3.5 % (2**64) }
t(:big_rem_f)   { (2**64).remainder(3.5) }
t(:big_divmod_f){ (2**64).divmod(3.5) }
t(:big_div_r)   { (2**64 + 88).div(Rational(4, 1)) }
t(:int_rem_r)   { 10.remainder(Rational(4, 1)) }

# The machine-int range is not symmetric anywhere: the magnitude of the
# minimum does not fit, so negating it, taking its absolute value and taking a
# gcd all have to promote. Three sites wrote the negation out themselves.
t(:neg_min)   { -(-9223372036854775808) }
t(:abs_min)   { (-9223372036854775808).abs }
t(:send_neg)  { (-9223372036854775808).send(:-@) }
t(:gcd_min)   { (-9223372036854775808).gcd(-9223372036854775808) }
t(:lit_eq)    { [-9223372036854775808 == 0 - 9223372036854775808,
                 9223372036854775808.send(:-@) == -9223372036854775808,
                 (-9223372036854775808 + 0) == -9223372036854775808] }

# NaN is UNORDERED (every relation is false, <=> is nil) and has no phase; an
# INFINITE float is above every integer, however many digits it has.
nan = 0 / 0.0
inf = 1 / 0.0
t(:nan_cmp)  { [1.0 <=> nan, nan <=> 1.0, 1 <=> nan] }
t(:nan_rel)  { [1.0 <= nan, 1.0 < nan, 1.0 >= nan, 1 >= nan] }
t(:nan_id)   { [nan.equal?(nan), nan.arg.equal?(nan), nan.conjugate.equal?(nan)] }
t(:nan_pol)  { nan.polar }
t(:nan_num)  { [nan.numerator, nan.denominator, inf.numerator, inf.denominator] }
t(:inf_cmp)  { [inf <=> Float::MAX.to_i * 2, -Float::MAX.to_i * 2 <=> inf] }

# The precision argument: a Float or Rational one is converted with #to_int, a
# String / Symbol / nil one is refused -- and a RATIONAL receiver refuses them
# all in its own words ("not an integer") where an Integer or Float receiver
# names the conversion.
t(:prec_rat)  { [12.3.round(Rational(3, 2)), 12345.round(Rational(3, 2))] }
t(:prec_str)  { 12345.floor("x") }
t(:prec_nil)  { 12.3.ceil(nil) }
t(:prec_sym)  { 12345.truncate(:a) }
t(:rat_prec)  { Rational(1, 2).round(1.5) }
t(:rat_prec2) { Rational(1, 2).floor("x") }

# ...and an INFINITE float asks a non-numeric other for its own #infinite?,
# ordering by the two signs (ruby's flo_cmp does exactly this).
def infinite_as(v)
  o = Object.new
  o.define_singleton_method(:infinite?) { v }
  o
end
t(:inf_obj) { [inf <=> infinite_as(1), inf <=> infinite_as(-1), inf <=> infinite_as(nil),
               -inf <=> infinite_as(1), -inf <=> infinite_as(-1), -inf <=> infinite_as(nil),
               1.0 <=> infinite_as(1), inf <=> Object.new] }
