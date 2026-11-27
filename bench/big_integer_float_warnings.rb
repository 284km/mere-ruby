# Deterministic public numeric-conversion controls; pass --seed=1.
srand(1)
kind = ARGV[0] || "integer"
count = ARGV[1].to_i
count = 100_000 if count == 0
$VERBOSE = nil
value = case kind
when "integer"
  sum = 0
  count.times { |i| sum += (i + 3) * 2 if i < count }
  sum
when "float"
  sum = 0.0
  count.times { |i| sum += (i * 0.5 + 1.5) / 2.0 if i * 0.5 < count }
  sum
when "rational"
  a = Rational(1, 3)
  b = Rational(1, 7)
  sum = 0
  count.times { sum += a + b if a > b }
  sum
when "mixed"
  big = 2**70
  sum = 0.0
  count.times { sum += big + 1.0 }
  sum
when "to_f"
  big = 2**70
  sum = 0.0
  count.times { sum += big.to_f }
  sum
when "float_loop"
  sum = 0.0
  count.times { |i| sum = sum + i * 0.5 * 1.5 }
  sum
when "builtin_calls"
  s = "abc"
  a = [1, 2, 3]
  sum = 0
  count.times { sum += s.size + a.first + a.size }
  sum
when "warnings"
  $VERBOSE = true
  warnings = []
  Warning.define_singleton_method(:warn) { |message| warnings[0] = (warnings[0] || 0) + 1 }
  big = 2**5000
  count.times { big.to_f }
  warnings[0]
else
  raise ArgumentError, kind
end
p value
