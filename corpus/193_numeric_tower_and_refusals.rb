# A bignum is exact wherever it goes, and a refusal names what it refused.

B = 10**20
p B * Rational(1, 2)
p B + Rational(1, 2)
p B - Rational(1, 2)
p B / Rational(1, 2)
p Rational(1, 2) + B
p Rational(1, 2) * B
p Rational(1, 2) / B
p B * Complex(1, 2)
p Complex(1, 2) * B
p B == Rational(B, 1)
p Rational(B, 1) == B
p B.gcdlcm(35)
p B.fdiv(10**19)
p((2**64 + 1) <=> (2**64))
p Rational(1, 2).hash == Rational(1, 2).hash
p Rational(1, 2).hash == Rational(1, 3).hash
p Complex(1, 2).hash == Complex(1, 2).hash

# what the numbers refuse, and in whose words
def refusal
  yield
  :no_refusal
rescue StandardError => e
  [e.class, e.message]
end
p refusal { 7.divmod(0) }
p refusal { 7.div(0) }
p refusal { 7 % 0 }
p refusal { 7.gcd("x") }
p refusal { 7.lcm(1.5) }
p refusal { 7.downto("x") { } }
p refusal { 7.upto("x") { } }
p refusal { 7.allbits?(Object.new) }
p refusal { 1.0.fdiv("x") }
p refusal { Rational(1, 2).div("x") }
p refusal { 1.0 % Complex(1, 2) }
p refusal { eval(Object.new) }

# ...and what converts instead of refusing
three = Object.new
def three.to_int = 3
p 7.allbits?(three)
p 7.anybits?(three)
p 1.coerce("2")
p 1.0.coerce("2")
p Float("1.")
p Complex(1, 2) ** Complex(1, 2)

# a pattern's flags, and what they mean for equality
p [/x/n.inspect, /x/n.options, Regexp.new("x", Regexp::NOENCODING).options]
p(/x/ == Regexp.new("x", Regexp::NOENCODING))
p(/\/foo\/bar/.inspect)
p refusal { Regexp.new(Object.new) }
p refusal { "x" =~ /x/; Regexp.last_match(1, 2) }
p refusal { r = /x/; r.freeze; r.send(:initialize, "y") }

# an exception carries what it was made of
begin
  raise "first"
rescue => e
  copy = e.exception("second")
  p [copy.class, copy.message, e.message]
  loc = e.backtrace_locations.first
  p [loc.class, loc.lineno.is_a?(Integer), loc.label.is_a?(String)]
end
p Errno::EOPNOTSUPP.new.errno == Errno::EOPNOTSUPP::Errno
