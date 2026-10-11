# Complex arithmetic as complex.c writes it (note 311): a real right operand
# leaves the imaginary part alone, Infinity * 0 inside a product is 0
# (safe_mul), an exact 0 added keeps a -0.0, powers at the special angles
# are exact, a whole Rational exponent is an Integer one, a real base takes
# a Complex exponent, `.33`.to_c reads, Complex() is an arity error, and a
# redefined Integer / Float / Rational operator is what the parts use.
c = Complex(Float::INFINITY, 0)
p c * Complex(1, 0), c * Complex(0, 1), Complex(0, Float::INFINITY) * Complex(1, 0), Complex(0, Float::INFINITY) * Complex(0, 1)
p Complex(-0.0, 0) * Complex(0, 0), Complex(1, 2) * 3, Complex(1.5, 2) * 2.0, Complex(Float::INFINITY, 0) * 2, 3 * Complex(1, 2)
p Complex(1, 2) + 3, Complex(1, 2.0) - 0.5, 2 - Complex(1, 2), Complex(Float::NAN, 0) * Complex(0, 0)
p Complex(1r, 2) * Complex(3, 1r), Complex(2, 3) * Complex(2, 3)
c = Complex(1, 2)
p c ** 2, c ** -2, c ** Rational(2), c ** Rational(-2), c ** Complex(2, 0), c ** 0, c ** 1
p Complex(1, 0) ** 100000000000000000000000000000000
p Complex(-1, 0) ** 10000000000000000000000000000000, Complex(-1, 0) ** 10000000000000000000000000000001
p Complex(0, 1) ** 100000000000000000000000000000000, Complex(0, 1) ** 100000000000000000000000000000001
p Complex(0, 1) ** 3, Complex(1, 1) ** 4, Complex(1, -1) ** 5, Complex(-2, 2) ** 3, Complex(2.0, 2.0) ** 2, Complex(0, -3) ** 3
p Complex(3, 0) ** 4, Complex(-2, 0) ** 3, Complex(0.5, 0) ** 2, Complex(1, 2) ** 3, Complex(Rational(1, 2), Rational(1, 2)) ** 2
p Complex(1, 1) ** -2, Complex(0, 2) ** -1
p ".33".to_c, "-.33".to_c, "-0.3_3".to_c, ".5i".to_c, "1+.5i".to_c, ".".to_c, ".e1".to_c, Complex(".5"), ".5".to_r, Rational(".5") rescue p $!
p Math.sqrt(Complex(1, 2) * Complex(1, 2).conj), 1 ** Complex(1), 2 ** Complex(3, 0)
begin; Complex(); rescue ArgumentError => e; p e.message; end
begin; Complex(1, 2, 3); rescue ArgumentError => e; p e.message; end
class Rational; remove_method :*; def *(o) = 355/113r; end; p Complex(2r, 0r) * Complex(1, 2)
p Math.sqrt(Complex(0, -0.0))
