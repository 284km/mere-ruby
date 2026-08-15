# `pack("E")` hands out the BYTES of a double. There is no bit view of a float
# here, so the three IEEE-754 fields are recovered by scaling -- and the test
# of that is a round trip: whatever comes back has to be the same double, for
# ordinary values, for zero (both signs), for a subnormal, and for infinity.
vals = [1.23, -4.56, 0.0, -0.0, 1.0, 0.1, 100000.0, 3.141592653589793]
p vals.map { |v| [v].pack("E").bytes }
p vals.map { |v| [v].pack("G").bytes }
p vals.map { |v| [v].pack("e").bytes }
p vals.map { |v| [v].pack("g").bytes }
p vals.all? { |v| [v].pack("E").unpack("E") == [v] }
p vals.all? { |v| [v].pack("G").unpack("G") == [v] }
p [1.23, 2.46].pack("E*").unpack("E*")
p [1.5, -2.25].pack("e*").unpack("e*")
p [1.5].pack("D").unpack("D")
p [1.5].pack("f").unpack("f")

# the ends of the range: the smallest normal, the largest finite, one
# subnormal, and the two infinities
p [Float::MIN, Float::MAX, Float::EPSILON, Float::DIG, Float::MANT_DIG,
   Float::MIN_EXP, Float::MAX_EXP, Float::RADIX]
p [Float::MIN / 2, Float::MAX, Float::INFINITY, -Float::INFINITY].map { |v| [v].pack("E").bytes }
p [Float::NAN].pack("E").bytes
p [Float::MIN / 3].pack("E").unpack("E")
p "\x00\x00\x00\x00\x00\x00\xf0\x7f".b.unpack("E")

# `buffer:` appends to a string the caller owns and answers that string
b = +"x"
[1.23, 2.46].pack("E*", buffer: b)
p b[1..].unpack("E*")

# a radix literal wider than a machine int is still exact
p 0xff00_fabcafe0_00ff
p 0xffffffffffffffff
p [0xff, 0o777, 0b1111, 017]

# Integer#[] takes a RUN of bits, not just one
p [255[0, 4], 255[4, 4], 3[0, 0], 5[1], 0b1011[0..2], 0b1011[1...3]]
