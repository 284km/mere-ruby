# Integer's >> << & | ^ % / of two Integers, by the fast path where it is
# sure (a shift inside the width, a division of non-negatives) and by the
# general one everywhere else: a negative shift count, one past the width,
# an overflowing <<, a negative operand of / or %, a zero divisor, and a
# Bignum on either side. And an operator the program redefined is called.
vals = [0, 1, -1, 7, -7, 3, 100, -100, 2**61, -(2**61), 2**62 - 1, -(2**62), 4611686018427387903, 2**64, -(2**64)]
shifts = [0, 1, -1, 2, -2, 31, 32, 61, 62, 63, 64, 65, 100, -100]
def r809 = yield rescue $!.class
out = []
vals.each do |a|
  shifts.each { |b| out << r809 { a >> b } << r809 { a << b } }
  vals.each { |b| out << r809 { a & b } << r809 { a | b } << r809 { a ^ b } << r809 { a % b } << r809 { a / b } }
end
p out.size
out.each_slice(60) { |s| p s }
x = 37
p [x >> 2, x << 3, x & 12, x | 64, x ^ 5, x % 6, x / 6]
class Integer
  def >>(o) = :redef_shr
  def &(o) = :redef_and
  def %(o) = :redef_mod
end
p [8 >> 1, 8 & 1, 8 % 3, 8 | 1, 8 << 1]
