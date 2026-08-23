# The numeric protocol is one protocol, and it was answered by some of the
# classes that share it.
#
# numerator / denominator worked for Integer and Rational and said "undefined
# method" for Float and Complex; fdiv was missing on Rational; #i was missing
# everywhere; polar's angle was a Float where ruby gives an Integer.
#
# rationalize is a separate question from to_r and was absent: ruby answers the
# SIMPLEST fraction within the receiver's precision, so 0.3.rationalize is
# (3/10) while 0.3.to_r is (5404319552844595/18014398509481984).

# --- an exact pair, for every member of the tower ------------------------
p [1.numerator, 1.denominator]
p [1.5.numerator, 1.5.denominator]
p [Rational(1, 2).numerator, Rational(1, 2).denominator]
p [0.1.numerator, 0.1.denominator]
# a Complex puts its parts over their common denominator
p Complex(Rational(1, 2), Rational(1, 3)).numerator
p Complex(Rational(1, 2), Rational(1, 3)).denominator
p Complex(1, 2).numerator
p Complex(1, 2).denominator

# the pair reconstructs the value
p Rational(1.5.numerator, 1.5.denominator) == 1.5.to_r
p Rational(0.1.numerator, 0.1.denominator) == 0.1.to_r

# --- fdiv is Float division for every one of them ------------------------
p 7.fdiv(2)
p 1.5.fdiv(2)
p Rational(1, 2).fdiv(2)
p Complex(1, 2).fdiv(2)
p (2**64).fdiv(2)

# --- Numeric#i is the imaginary axis -------------------------------------
p 1.i
p 1.5.i
p Rational(1, 2).i
p((2**64).i)

# --- polar's angle is an Integer when there is no rotation ---------------
p 1.polar
p 0.polar
p 1.5.polar
p((-1).polar)
p Complex(0, 1).polar == [1, Math::PI / 2]

# --- rationalize: the simplest fraction, not the exact one ---------------
p 1.rationalize
p Rational(1, 2).rationalize
p 0.3.rationalize
p 0.1.rationalize
p 1.5.rationalize
p 2.5.rationalize
p((-0.3).rationalize)
p 0.0.rationalize
p nil.rationalize

# with an explicit tolerance the interval widens and the answer simplifies
p 0.3.rationalize(0.01)
p 3.14159.rationalize(0.001)
p 3.14159.rationalize(Rational(1, 100))

# to_r is the OTHER question, and still answers exactly
p 0.3.to_r
p 1.respond_to?(:rationalize)
