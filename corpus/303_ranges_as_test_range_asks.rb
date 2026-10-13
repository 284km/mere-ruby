# Range as CRuby's test_range asks it (note 325): an endless integer step
# carries on in bignums instead of wrapping past 2**63; an endless or
# beginless bsearch finds an answer beyond an int; ends that cannot be
# compared neither overlap nor cover; a begin with #to_str walks as a String
# and an endless range of #succ objects walks until a break; a Rational end
# is counted; a Time range's step needs a step.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { m = 2**62; a = []; (m..).step(m) { |x| a << x; break if a.size == 4 }; a }
t(2) { a = []; (2**63 - 3..2**63 + 1).step(2) { |x| a << x }; a }
t(3) { b = 2**100; [(0...).bsearch { |i| i > b * 2 }, (b...).bsearch { |i| i > b * 2 }, (...0).bsearch { |i| i > -b * 2 }, (0..).bsearch { |i| i >= 5 }] }
t(4) { [(1..3).overlap?('a'..'d'), (1..).overlap?('a'..), (..1).overlap?(..'a'), (1..5).overlap?(3..), (..2).cover?(.."2"), (..2).cover?(..1)] }
o = Object.new
class << o; def to_str() "a" end; def <=>(other) to_str <=> other end; end
t(5) { a = []; (o.."c").each { |x| a << x }; b = []; (o..).each { |x| b << x; break if b.size >= 3 }; [a, b] }
S303 = Struct.new(:i) { def succ = self.class.new(i + 1); def <=>(o) = i <=> o.i }
t(6) { r = []; (S303.new(0)..).each { |d| r << d.i; break if d.i >= 4 }; r }
t(7) { [(1...5r).size, (1..5r).size, ((Time.at(0)...Time.at(9)).step rescue $!.message)] }
