values = [0.0, -0.0, 0.5, 1.0, 1.5, 2.0, Math::E, 3.0, 8.0, 10.0, 100.0, 1000.0, 0.1, 7.5,
          -0.5, -1.0, -2.0, -8.0, 1.0e-300, -1.0e-300, 1.0e300, -1.0e300,
          Float::MIN, Float::MAX, Float::INFINITY, -Float::INFINITY]
puts values.map { |value| Math.cbrt(value) }.pack('G*').unpack1('H*')
p Math.cbrt(Float::NAN).nan?
