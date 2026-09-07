# ---- 1. Complex answers questions ABOUT itself ----------------------------
INF = Float::INFINITY

# #finite? said false for every exact shape, which is not "unknown" -- it is
# "this number is infinite". The same catch-all covered bignums and rationals.
p [Complex(1, 2).finite?, Complex(1.0, 2.0).finite?, Complex(INF, 0).finite?,
   Complex(0, INF).finite?, Complex(Float::NAN, 0).finite?, Complex(2**70, 0).finite?]
p [(2**70).finite?, Rational(1, 2).finite?, 1.finite?, 1.0.finite?, INF.finite?]
# #infinite? is 1 whenever EITHER part is, with no sign
p [Complex(INF, 0).infinite?, Complex(0, INF).infinite?, Complex(-INF, 0).infinite?,
   Complex(1, 2).infinite?, Complex(Float::NAN, 0).infinite?,
   (2**70).infinite?, Rational(1, 2).infinite?]

# eql? is PART-WISE and class-strict, which is stricter than ==
p [Complex(1, 2).eql?(Complex(1, 2)), Complex(1, 2).eql?(Complex(1.0, 2.0)),
   Complex(1.0, 2.0).eql?(Complex(1.0, 2.0)), Complex(1, 2).eql?(Complex(1, 2.0)),
   Complex(1, 0).eql?(1), Complex(1, 2) == Complex(1.0, 2.0)]

# the sign of the imaginary part is the sign BIT, not `< 0`: -0.0 compares as
# non-negative, so this printed "1+-0.0i" -- not a Ruby literal at all. And a
# part that is not a plain finite number takes an explicit `*`.
p [Complex(1, -0.0).to_s, Complex(1, 0.0).to_s, Complex(-0.0, -0.0).to_s,
   Complex(1, -1).to_s, Complex(1, 1).to_s]
p [Complex(0, -INF).to_s, Complex(0, INF).to_s, Complex(0, Float::NAN).to_s]
p [Complex(1, -0.0).inspect, Complex(0, INF).inspect, Complex(1, Rational(1, 2)).inspect]

# #coerce answers two COMPLEXES: a bare Integer breaks the contract every
# caller of the protocol relies on. The other side keeps its own class inside.
p [Complex(1, 2).coerce(3), Complex(1, 2).coerce(3.5),
   Complex(1, 2).coerce(Complex(4, 5)), Complex(1, 2).coerce(Rational(1, 2))]
begin
  Complex(1, 2).coerce("x")
rescue => e
  puts "#{e.class}: #{e.message}"
end

# an ordering exists exactly when BOTH imaginary parts are zero
p [(Complex(2, 0) <=> Complex(1, 0)), (Complex(1, 0) <=> Complex(1, 0)),
   (Complex(1, 0) <=> Complex(2, 0)), (Complex(1, 1) <=> Complex(2, 0)),
   (Complex(2, 0) <=> 1), (1 <=> Complex(2, 0)), (Complex(2, 0) <=> "x")]
p Complex(2, 0).send(:<=>, Complex(1, 0))

# to_r accepts a FLOAT zero imaginary part, the way to_f already did
p [Complex(1, 0.0).to_r, Complex(1, 0).to_r, Complex(2.5, 0).to_r]
begin
  Complex(1, 2).to_r
rescue => e
  puts "#{e.class}: #{e.message}"
end

# a non-negative REAL base with a real exponent is a real power: exp(y*ln x)
# is a bit short of the exactly-rounded double ruby answers
p [Complex(2, 0) ** Rational(1, 2), Complex(4, 0) ** Rational(1, 2),
   Complex(2, 0) ** 2, Complex(2, 0) ** 0.5]

# ---- 2. pow's modulus is a divisor too ------------------------------------
[-> { 2.pow(3, 0) }, -> { (2**70).pow(3, 0) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
p [2.pow(3, 5), 2.pow(10, 1000)]

# ---- 3. slice_before / slice_after ---------------------------------------
# Both were in the list this interpreter uses to decide whether a name exists,
# with nothing behind them -- so the name was claimed and every call, block
# form included, was a NoMethodError.
p [[1, 2, 3].slice_before { |x| x == 2 }.to_a, [1, 2, 3].slice_before(2).to_a]
p [[1, 2, 3].slice_after { |x| x == 2 }.to_a, [1, 2, 3].slice_after(2).to_a]
p [[1, 2, 3].slice_before(2).class, [].slice_before(2).to_a, [1, 2].slice_after(9).to_a]
p [(1..4).slice_before { |x| x.even? }.to_a, ({a: 1}).slice_before { |k, v| false }.to_a]
class Countable
  include Enumerable
  def each
    yield 1
    yield 2
    yield 3
  end
end
p [Countable.new.slice_before(2).to_a, Countable.new.slice_after(2).to_a]
# ...and the two refuse DIFFERENTLY when given both a pattern and a block,
# which is ruby's wording and not a slip
[-> { [1].slice_before(1) { |x| true } }, -> { [1].slice_before },
 -> { [1].slice_after(1) { |x| true } }, -> { [1].slice_after }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end

# ---- 4. grep_v does not leave someone else's match behind ----------------
# grep_v yields the elements that did NOT match, and for each of those the last
# match attempt FAILED -- so $~ is nil inside the block. It used to hold the
# last SUCCESSFUL match, from an element grep_v threw away.
seen = []
["a", "e", "i"].grep_v(/e/) { |x| seen << [x, $~] }
p seen
hit = []
["a", "e", "i"].grep(/e/) { |x| hit << [x, $~ && $~[0]] }
p hit
# a non-Regexp pattern does not touch $~ at all
"zz" =~ /z/
before = $~[0]
[1, 2].grep_v(Integer) { |x| x }
p [before, $~ && $~[0]]
