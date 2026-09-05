# When a number meets something it does not know, it asks that thing to coerce
# itself -- and the answer decides. Beside it: the exact arithmetic that only
# Rational has, and the bit operations that only make sense in two's complement.

class Money
  attr_reader :cents
  def initialize(cents); @cents = cents; end
  def coerce(other); [Money.new(other * 100), self]; end
  def +(other); Money.new(cents + other.cents); end
  def -(other); Money.new(cents - other.cents); end
  def *(other); Money.new(cents * other.cents); end
  def /(other); Money.new(cents / other.cents); end
  def %(other); Money.new(cents % other.cents); end
  def div(other); cents / other.cents; end
  def <=>(other); cents <=> other.cents; end
  def to_s; "$" + (cents / 100.0).to_s; end
end

m = Money.new(250)
p((1 + m).to_s, (1 - m).to_s, (2 * m).to_s, (5 / m).to_s, (5 % m).to_s)
p(1 <=> m, 3 <=> Money.new(300), 1.div(m))
p((1.0 + m).to_s)

# ...and something that cannot coerce is refused by name
[-> { 1 + "x" }, -> { 1 + nil }, -> { 1 * Object.new }, -> { 1.coerce("x") },
 -> { 1.coerce(nil) }, -> { 1.0.coerce("x") }].each do |f|
  begin
    f.call
  rescue TypeError, ArgumentError => e
    puts e.class.to_s + ": " + e.message
  end
end
p(1 <=> "x", 1 <=> nil, 1.0 <=> nil)
p 1.coerce(2.0), 1.coerce(2), 1.0.coerce(2)

# Rational stays exact: modulo, power, and the refusals
p Rational(7, 2) % 1, Rational(7, 2) % Rational(1, 2), Rational(7, 2) % -1
p Rational(7, 2) % 1.5, Rational(-7, 2) % 2
p Rational(2, 3) ** 2, Rational(2, 3) ** -2, Rational(2, 1) ** Rational(2, 1)
p Rational(4, 1) ** Rational(1, 2), Rational(1, 2) ** 0.5
begin
  Rational(1, 2) % 0
rescue ZeroDivisionError => e
  puts e.message
end

# two's complement: a negative bignum has infinitely many leading ones
big = 2 ** 70
p big & 3, (-big) & 3, (-big) | 3, (-big) ^ 3, big ^ -3, (-big) & -3
p(-5 & 3, -5 | 3, -5 ^ 3, ~5, ~(-5))
p 1.allbits?(1), (-1).allbits?(3), (-2).anybits?(3), (-4).nobits?(3)
p (big + 1).allbits?(1), (-big).nobits?(1)

# the rest of the integer surface these specs reach
p 7.ceildiv(2), (-7).ceildiv(2), 7.ceildiv(-2), (2 ** 70).ceildiv(3)
p Integer.try_convert(3), Integer.try_convert("3"), Integer.try_convert(nil)
p 1.integer?, 1.5.integer?, Rational(1, 2).integer?
p 7.5 % 2, -7.5 % 2, 7.5 % -2, 7.5.fdiv(2)
p 7.remainder(2), (-7).remainder(2), 2.pow(10, 1000), 255.bit_length
r = []
3.downto(1.5) { |i| r << i }
u = []
3.upto(5.5) { |i| u << i }
p r, u
p Complex(1, 0) ** 0.0, Complex(2, 0) ** 2.0
