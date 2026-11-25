# % & | ^ << >> ** of two numbers -- Integers, Bignums, a negative one,
# Rationals, Floats where they take them -- and what each refuses, as a call
# written with an operator. And a program's own Integer#& and a refinement of
# Integer#|, which the operator reaches.
b = 1 << 70
vals = [b, 3, -b, Rational(3, 2), 0, -5]
r = []
vals.each do |x|
  vals.each do |y|
    r << (begin; x % y; rescue => e; e.class; end)
    r << (begin; x ** y; rescue => e; e.class; end) unless y.is_a?(Integer) && y.abs > 100
    next unless x.is_a?(Integer) && y.is_a?(Integer)
    r << (x & y) << (x | y) << (x ^ y)
    r << (x << y) << (x >> y) if y.abs < 100
  end
end
p r
p [2.5 % 2, 2.5 ** 2, -7.5 % b, b % 2.5]

board = (1 << 60) | 0b1010
masks = [0b1000, 0b0010, 0b0100, 1 << 60]
p masks.map { |m| [board & m == m, board | m, board ^ m, board[3]] }

p((b & nil rescue [$!.class, $!.message]))
p((b % 0 rescue [$!.class, $!.message]))
p((b << "x" rescue [$!.class, $!.message]))

class Integer
  def &(o) = :mine
end
p [b & 1, 3 & 1]

module R
  refine(Integer) { def |(o) = :refined }
end
using R
p [b | 1, 2 | 1]
