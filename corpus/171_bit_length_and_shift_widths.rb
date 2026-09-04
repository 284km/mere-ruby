# Integer#bit_length on a bignum, and the shift width's coercion.
#
# bit_length used to divide by 2 until it reached zero: for (2**10000) that is
# 33220 divisions, each producing a fresh 3011-digit string, and the process
# was killed at the 6 GB memory cap -- while BUILDING 2**10000 costs a quarter
# of a gigabyte. The count now comes from the digit count and is then checked
# against real powers of two, so the estimate decides nothing.
#
# The shift width goes through a coercion that raises TypeError the way CRuby
# does. arith_bin is a leaf helper with no world to raise from, so every
# refusal used to surface as a bare StandardError.

p 0.bit_length, 1.bit_length, 2.bit_length, 3.bit_length, 4.bit_length
p 0xff.bit_length, 0x100.bit_length, (2**12 - 1).bit_length, (2**12).bit_length
p (-1).bit_length, (-2).bit_length, (-3).bit_length, (-0x100).bit_length
p (-2**12 - 1).bit_length, (-2**12).bit_length, (-2**12 + 1).bit_length
p (2**64).bit_length, (2**1000 - 1).bit_length, (2**1000).bit_length, (2**1000 + 1).bit_length
p (2**10000 - 1).bit_length, (2**10000).bit_length, (2**10000 + 1).bit_length
p (1 << 100).bit_length, (1 << 100).succ.bit_length, (1 << 100).pred.bit_length
p (1 << 10000).bit_length

# the width converts, or is refused by type
class WidthLike
  def to_int; 3; end
end
class BadWidth
  def to_int; "three"; end
end

[3, 3.7, Rational(7, 2), WidthLike.new, "4", nil, :four, Object.new, BadWidth.new].each do |w|
  %w[<< >>].each do |op|
    begin
      puts "1 #{op} #{w.class}: #{1.send(op, w).inspect}"
    rescue => e
      puts "1 #{op} #{w.class}: #{e.class}: #{e.message}"
    end
  end
end

# a width past what a shift can express, and the bignum receiver
begin
  1 << (2**70)
rescue => e
  p e.class
end
p 1 >> (2**70)
p (2**70) >> 4, (2**70) << 4
p 3 << nil rescue p [$!.class, $!.message]
p((2**70) << "4") rescue p [$!.class, $!.message]

# A shift WIDER THAN THE NUMBER needs no power of two at all: everything is
# shifted out, and ruby's >> floors, so a negative value lands on -1. Building
# 2^(2**40) in order to divide by it is not an answer -- and shr_int halved one
# step at a time, so `1 >> (2**40)` was a loop of 1099511627776 iterations.
bignum_value = 2**64
p(-1 << -(2**40))
p(-bignum_value << -(2**40))
p(0 << -(2**40))
p(1 << -(2**40))
p(bignum_value << -(2**40))
p(0 << (2**40))
p(0 >> (2**40))
p(1 >> (2**40))
p(-1 >> (2**40))
p(-8 >> (2**40))
p(bignum_value >> (2**40))
p(-bignum_value >> (2**40))
p(0 >> -(2**40))
p(bignum_value << 4)
p(-bignum_value << 9)
p(bignum_value << -1)
p(-bignum_value << -2)
p((-2**63) >> -1)
p 255 >> 4, 255 >> 8, 255 >> 9, (-255) >> 8, (-255) >> 9
p((2**64) >> 100)
