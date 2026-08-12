# Rational() with a Float or String argument was silently zero: num_dec
# answered "0" for anything that was not an Integer, so Rational(2.5) was
# (0/1) and Rational(1, 2.54) divided by zero. sassc writes the latter.
p Rational(2.5)
p Rational(0.5)
p Rational(-1.5)
p Rational(1, 2.54)
p Rational(1.5, 0.5)
p Rational(2.5, 2)
p Rational(1, 2)
p Rational(3, 4) + Rational(1, 4)

p Rational("3/4")
p Rational("2.5")
p Rational("7")
p Rational("-3/8")

p Rational(2.5).class
p Rational(1, 2.54) < 1
p Rational(2.5) == Rational(5, 2)
p Rational(2.5).to_f
p [Rational(1, 3), Rational(1, 2)].sort.map(&:to_s)
p 1.quo(3)
