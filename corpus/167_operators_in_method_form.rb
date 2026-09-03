# An operator called in method form is the operator. Every one of these was a
# NoMethodError, and `===` was worse than that: `x.===(y)` parsed as an
# attribute assignment to `x.==` and answered the ARGUMENT.
p ["s".==("s"), "s".!=("t"), "s".===("s"), "s".<("t"), "s".<=>("t"), "s".+("t"), "s".*(2), "s".%([]), "s".=~(Regexp.new("s"))]
p [[1].==([1]), [1].+([2]), [1,2].-([2]), [1,2].&([2]), [1].|([2]), [1].*(2), [1].<=>([2])]
p [({a: 1}).==({a: 1}), ({a: 1}).<({a: 1, b: 2}), ({a: 1}).<=({a: 1}), ({a: 1}).>=({a: 1}), ({a: 1}).>({})]
p [:a.==(:a), :a.===(:a), :a.<=>(:b), :a.=~(Regexp.new("a"))]
p [1.==(1), 1.<=>(2), 1.+(2), 1.-(2), 1.*(2), 1./(2), 1.%(2), 1.**(2), 1.<<(2), 1.>>(1), 1.&(3), 1.|(2), 1.^(3), 1.~]
p [1.5.==(1.5), 1.5.+(0.5), 1.5.<=>(2.0), 1.5.**(2)]
p [(1..3).===(2), (1..3).==(1..3), (1..3).%(2).class, ((1..3) % 2).to_a]
p [nil.&(true), nil.|(true), nil.^(true), nil.===(nil)]
p [true.&(false), true.|(false), true.^(true), true.===(true)]
p [false.&(true), false.|(true), false.^(false), false.===(false)]
p [Regexp.new("a").==(Regexp.new("a")), Regexp.new("a").===("a"), Regexp.new("a").=~("a")]
p [Comparable.==(Comparable), String.===("s"), String.==(String)]
p [Rational(1,2).==(Rational(1,2)), Rational(1,2).+(Rational(1,2)), Complex(1,2).==(Complex(1,2)), Complex(1,2).+(Complex(1,2))]
p [(1..3).to_a.reduce(:+), [1,2,3].each_slice(2).to_a]
# the sender agrees with the operator, and a user-defined one still wins
p ["s".send(:===, "s"), "s".send(:==, "s"), 1.send(:+, 2)]
class Eq; def ==(o); :mine; end; def ===(o); :mine3; end; end
p [Eq.new == Eq.new, Eq.new.==(Eq.new), Eq.new === Eq.new, Eq.new.===(Eq.new), Eq.new.send(:==, Eq.new)]
# and a setter is still a setter
class W; attr_accessor :v; end
w = W.new
p [(w.v = 7), w.v, w.send(:v=, 8), w.v]
