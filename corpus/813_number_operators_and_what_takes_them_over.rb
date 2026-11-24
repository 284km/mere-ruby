# + - * / < <= > >= of two builtin numbers -- an Integer, a Bignum, a Float,
# a Rational, a Complex -- in every pairing, and what takes the operator
# over: a method the program defines on the class, an alias, an undef, a
# refinement, a subclass, a number that is an object (coerce), a Complex
# with an object in it. What a builtin refuses names the builtin.
nums = [3, 2**70, 2.5, Rational(1, 3), Complex(1, 2), Complex(1.5, -2)]
ops = %i[+ - * / < <= > >=]
nums.each do |a|
  nums.each do |b|
    row = ops.map do |op|
      case op
      when :+ then a + b
      when :- then a - b
      when :* then a * b
      when :/ then a / b
      when :< then (a < b rescue $!.class)
      when :<= then (a <= b rescue $!.class)
      when :> then (a > b rescue $!.class)
      else (a >= b rescue $!.class)
      end
    end
    p [a, b, row]
  end
end

# exact: a Float against an Integer it cannot hold
big = 2**53 + 1
p big.to_f < big, big.to_f == big, big > big.to_f, 9007199254740993 > 9007199254740992.0
nan = Float::NAN
p nan < 1, 1 < nan, nan > 1.0, 1.0 >= nan, (nan + 1).nan?, 1 / 2.0, 7 / 2, -7 / 2, 7.0 / 2, 1 / Rational(2, 3)
p 1 / 0.0, -1 / 0.0, (0 / 0.0).nan?, 1.0 / 0, 2**64 / 2.0

# what a builtin refuses
[-> { 1 / 0 }, -> { 2**70 / 0 }, -> { Rational(1, 2) / 0 }, -> { 1 + nil }, -> { 1.5 < "x" }, -> { Rational(1, 2) > nil },
 -> { Rational(1, 2) >= Complex(1, 2) }].each do |f|
  f.()
rescue => e
  p [e.class, e.message, e.backtrace_locations&.first&.label]
end
# (a Complex has no ordering, on either side of an Integer or a Float)
[-> { Complex(1, 2) < Complex(1, 3) }, -> { 1 < Complex(1, 1) }, -> { 2.5 <= Complex(1, 0) }, -> { 2**70 > Complex(1, 2) }].each do |f|
  f.()
rescue => e
  p [e.class, e.message]
end
# (a Fixnum times a Complex multiplies each part: an Integer part stays one)
p 3 * Complex(1.5, -2), Complex(1.5, -2) * 3, 2.5 * Complex(1, 2), (2**70) * Complex(1.5, -2), 3 + Complex(1.5, -2), 3 - Complex(1.5, -2)

# a number that is an object: coerce is asked
class N813
  def initialize(v) = (@v = v)
  def coerce(o) = [N813.new(o), self]
  def +(o) = [:n_plus, @v, (o.is_a?(N813) ? o.v : o)]
  def <(o) = :n_lt
  attr_reader :v
end
n = N813.new(5)
p 1 + n, 1.5 + n, (2**70) + n, Rational(1, 2) + n, 1 < n, 1.5 < n, n + 1
c = Complex(n, 1) rescue p($!.class)

# a subclass of a number's class is not the number
class F813 < Numeric
  def coerce(o) = [o, 10]
  def +(o) = :sub_plus
end
p 1 + F813.new, 2.0 * F813.new, F813.new + 1

# a method the program defines takes the operator; the alias it kept gives
# the builtin back
class Float; alias_method :mul813, :*; def *(o) = :float_mul; end
x = 1.5
p x * 2, x * 2.0, 2 * x, Complex(1, 2) * x
class Float; alias_method :*, :mul813; end
p x * 2, 2 * x
class Complex; alias_method :plus813, :+; def +(o) = :cpx_plus; end
z = Complex(1, 2)
p z + z, z + 1, 1 + z
class Complex; alias_method :+, :plus813; end
p z + z
class Rational; alias_method :minus813, :-; def -(o) = [:rat_minus, minus813(o)]; end
r = Rational(3, 4)
p r - 1, r - r, 1.5 - r
class Rational; alias_method :-, :minus813; end
p r - 1
class Integer; alias_method :lt813, :<; def <(o) = :int_lt; end
i = 2**70
p i < 1, 3 < 2.5, 2.5 < 3
class Integer; alias_method :<, :lt813; end
p i < 1, 3 < 2.5

# undef: the operator is gone, for that class only
class Complex; undef_method :-; end
p((z - 1 rescue $!.class), 1.5 - 1, (z - z rescue $!.class), 3 - 1)

# a refinement, in a file scope of its own
module R813
  refine Float do
    def /(o) = :refined_div
  end
end
using R813
p 3.0 / 2, 3 / 2.0, 3.0 / 1.5
