# Integers, Floats and Rationals as CRuby's test_integer, test_numeric and
# test_rational ask them (note 344): a negative precision past an int is a
# bignum, Float#floor/#ceil at a precision check the next candidate, ceildiv
# divides with #div, pow(b, m) works on bignums, Integer#[] slices exactly,
# remainder by infinity and between Rationals is ruby's, an exact 0 or 1 to
# a Rational power stays exact, and the conversions refuse as ruby does.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { [1.ceil(-20), -1.floor(-20), 1.ceil(-50), 7.floor(-19), 12345.ceil(-2)] }
t(2) { (1..16).map { |i| [291.4.floor(i), 291.4.ceil(i), 0.3.floor(i), -2.675.ceil(i)] }.uniq }
t(3) { [3.ceildiv(1.2), 3.ceildiv(6/5r), 4.ceildiv(-3), (10**100 - 11).ceildiv(10**99 - 1)] }
t(4) { [2120078484650058507891187874713297895455.pow(5478118174010360425845660566650432540723, 5263488859030795548286226023720904036518), 3.pow(2**70, 7), (2**80).pow(3, -1000)] }
t(5) { n = -16; [n[-66, 71], n[-34, 40], (2**64)[60, 10], (2**64)[-3, 70], n[-66..4], 5[1, 2]] }
t(6) { [(25 * 10**70).round(-71, half: :even) == 2 * 10**71, (-25 * 10**70).round(-71, half: :down) == -2 * 10**71, (35 * 10**70).round(-71, half: :even) == 4 * 10**71] }
t(7) { [4.remainder(Float::INFINITY), -4.remainder(Float::INFINITY), 4.remainder(-Float::INFINITY), Rational(1, 2).remainder(Rational(2, 3)), Rational(-7, 2).remainder(2)] }
t(8) { [Rational(0) ** Rational(2, 3), 0 ** Rational(2, 3), 1 ** Rational(1, 2), Rational(4) ** Rational(1, 2), (Rational(0) ** Rational(-2, 3) rescue $!.class)] }
t(9) { o = Object.new; def o.to_int = 10; [10.digits(o), 1.digits(10r), 1.digits(10.0), (10.digits("a") rescue $!.class), (10.digits(10 + 1i) rescue $!.class)] }
t(10) { o = Object.new; def o.to_i = raise("x"); [Integer(o, exception: false), Rational("1/0", exception: false), "5e_1".to_r, "5e_1".to_c, Rational(1, 10**23).to_f] }
