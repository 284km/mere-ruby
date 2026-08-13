# A negative base raised to a non-integer power has no real root: ruby answers
# the principal complex one. A half-integer exponent is a quarter turn, where
# the real part is exactly zero.
p [(-8) ** 0.5, (-8) ** 1.5, (-8) ** 2.5, (-8) ** -0.5, (-8) ** -1.5]
p [(-2.0) ** 0.5, (-1) ** 0.5, (-0.25) ** 0.5]
p ((-8) ** (1.0 / 3)).class
p ((-8) ** (1.0 / 3)).imaginary

# an integer exponent stays real, and a positive base is untouched
p [(-8) ** 2, (-8) ** 3, (-8.0) ** 3, (-8) ** -1, 4 ** 0.5, 8 ** (1.0 / 3), 2 ** 10]

# File.binwrite writes the bytes it is given, zero bytes included.
path = "/tmp/mere_ruby_corpus_105.bin"
data = "a\0b\xff\0c"
File.binwrite(path, data)
back = File.binread(path)
p [back.bytesize, back == data.b, back.encoding.to_s]
File.delete(path)
p File.exist?(path)
