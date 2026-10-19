# The numeric tower as test_numeric, test_rational and test_complex ask
# (note 379): Float#remainder by an infinity, modular pow past 2**31, step's
# arity and zero step, quo without #to_r, #remainder through coerce, == with
# a Comparable, a Symbol named by its #inspect under a US-ASCII default,
# super into Kernel#inspect, Rational's zero predicates and coerce with a
# Complex, a fractional denominator in "5/3.3", Rational() of a Complex, the
# 1.8 marshal form, define_method with `it`, Complex with object parts,
# Complex division the way complex.c rounds it, and unknown keywords.
def t(label)
  r = yield
  p [label, r]
rescue => e
  p [label, e.class, e.message.sub(/0x\h+/, "0x")]
end
p [4.2.remainder(-Float::INFINITY), -4.2.remainder(Float::INFINITY), 4.remainder(-Float::INFINITY)]
p 12.pow(72387894339363242, 243682743764), 3.pow(10**18, 10**12 + 39)
t(:step_arity) { 1.step(10, 1, 0) {} }
t(:step_zero) { 1.step(10, 0) }
t(:step_nil_block) { 1.step(10, nil) {} }
p 1.step(10, nil).size
t(:numeric_quo) { Numeric.new.quo(1) }
x = Class.new { def coerce(a) = [self, a]; def %(a) = self }.new
t(:coerced_remainder) { 1.remainder(x) }
mi = Class.new do
  include Comparable
  def initialize(i) = @i = i
  attr_reader :i
  def <=>(o) = @i <=> (o.is_a?(self.class) ? o.i : o)
end
m = mi.new(5)
p [5 == m, m == 5, 5.0 == m, [5].include?(m), [m].index(5), 6 == m]
o = Object.new
def o.==(x) = x == 5
p [[5].include?(o), [5].index(o), [5].count(o)]

class Numeric
  def inspect = super.freeze
end
p Numeric.new.inspect.sub(/0x\h+/, "0x")
class Foo355
  def initialize = @a = [1]
  def inspect = "<" + super + ">"
  def to_s = "!" + super
end
p Foo355.new.inspect.sub(/0x\h+/, "0x"), Foo355.new.to_s.sub(/0x\h+/, "0x")
class E355 < StandardError
  def inspect = super
end
p E355.new("m")

p [0r.positive?, 0r.nonzero?, 1r.coerce(Complex(2, 0)), 1r.coerce(Complex(2, 1)), 1.coerce(Complex(2, 0))]
t(:int_coerce_complex) { 1.coerce(Complex(2, 1)) }
p ["5/3.3".to_r, "5/3e1".to_r, "5/3._3".to_r, Rational("5/3.3"), "5/3.3".to_c, "_5".to_c]
p [Rational(Complex(1, 2), 2), Rational(Complex(1, 2), Complex(1, 2)), Rational(2, Complex(1, 2))]
p Marshal.load("\x04\x08o:\x0dRational\x07:\x11@denominatori\x07:\x0f@numeratori\x06")
p Marshal.load("\x04\x08o:\x0cComplex\x07:\x0a@reali\x06:\x0b@imagei\x07")
t(:marshal_nil_numerator) { Marshal.load("\x04\x08o:\x0dRational\x07:\x11@denominatori\x07:\x0f@numerator0") }

c = Class.new(Numeric)
num = 0
c.define_method(:to_s) { num.to_s }
c.define_method(:==) { num == it }
c.define_method(:<) { num < it }
n = c.new
p Complex(3, n).to_r
num = 1
t(:complex_to_r) { Complex(3, n).to_r }
c.define_method(:to_r) { 0r }
p Complex(3, n).to_r
p c.instance_method(:==).arity
c2 = Complex(Numeric.new, 1)
p c2.inspect.sub(/0x\h+/, "0x"), c2.to_s.sub(/0x\h+/, "0x")
p Complex(1, 2).fdiv(Complex(2, 3)), Complex(1.5, -2) / Complex(0.5, 7), 1.5 / Complex(2), Complex(1) <=> 2
t(:unknown_keyword) { Complex(Complex(1, 0), bad_keyword: true) }
t(:unknown_keywords) { Integer("1", a: 1, b: 2) }
t(:rational_no_args) { Rational() }
t(:rational_three_args) { Rational(1, 2, 3) }
t(:step_unknown_keyword) { 1.step(10, foo: nil) {} }
p Rational("1e-99999999999999999999"), "1e-99999999999999999999".to_r
t(:huge_positive_exponent) { "1e99999999999999999999".to_r }
t(:rational_nan) { Rational(0.0 / 0) }
t(:rational_inf) { Rational(-1.0 / 0, 2) }
t(:step_hash) { 1.step(10, {by: "1"}).next }
t(:step_by_string) { 1.step(10, by: "1") {} }
t(:step_to_string) { 1.step(to: "10").size }
S355 = Struct.new(:a) do
  def inspect = "S" + super
end
p S355.new(1)
class T355 < Time
  def inspect = "T" + super
end
p T355.at(0).utc
