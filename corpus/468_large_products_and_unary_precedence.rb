# products of thousands of limbs (by NTT) agree with the schoolbook ones
srand(11)
[[1300, 1300], [1201, 5000], [20000, 20000], [3, 50000]].each do |la, lb|
  a = rand(10**la)
  b = rand(10**lb)
  c = a * b
  p [c.to_s.size, c.to_s[0, 12], c.to_s[-12..], c % 1_000_000_007, c == b * a]
end
x = 12345678901234567890 ** 2000
p x.to_s.size, x % 1_000_003, (x * x) % 1_000_003, (x * x) / x == x

# a large power is built, and one past what is built is refused
y = 4 ** 4_000_000
p y.to_s.size, y % 1_000_003, y.bit_length
p 4r ** 1000 == 4 ** 1000, (1 / 4r) ** 3 == 1r / 64
p((begin; 4r ** 400000000000000000000; rescue ArgumentError => e; e.message; end))

# `!` and `~` bind tighter than `**`; unary minus does not
v = 3
p ~2**2, -2**2, +2**2, ~-2**2, -~2**2, ~v**2, -v**2
p ~1**11 + -~1**~1**3
p((begin; !true**2; rescue NoMethodError => e; e.class; end))
# 1 and -1 to a negative power are Integers
p 1**-2, (-1)**-3, (-1)**-2, 2**-2, (1**-2).class
