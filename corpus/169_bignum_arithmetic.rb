# The magnitude routines build their result in one buffer now, and `**`
# squares instead of multiplying e times. Both are rewrites of arithmetic that
# was already correct, so this file is the shape of the check: every carry,
# borrow and digit boundary, against the reference.
p [2**64, 2**100, 2**1000 % 1000003, (2**10000).to_s.size]
p [10**20 + 1, 10**20 - 1, 999999999999999999999 + 1, 1000000000000000000000 - 1]
p [(2**70) + (2**70), (2**70) - (2**70), (2**70) * (2**70), (2**140) / (2**70)]
p [(2**70) % 7, (2**70) % (2**35), -(2**70) % 7, (2**70) % -7]
p [(-2)**101, (-2)**100, (-3)**7, 0**0, 1**100000, 0**5]
p [(1..30).reduce(:*), (1..30).reduce(:*) / (1..29).reduce(:*)]
p [12345678901234567890 * 98765432109876543210, 99999999999999999999 + 1]
p [(2**64 - 1) + 1, (2**64) - 1, (2**63) * 2, -(2**63) * 2]
p [123456789 * 0, 0 * (2**70), (2**70) * 1, 1 * (2**70)]
# carries that ripple the whole length, and borrows that do
p [10**50 - 1 + 1, 10**50 - (10**50 - 1), (10**50 - 1) + (10**50 - 1)]
p [(10**30 - 1) * 9, (10**30 - 1) * (10**30 - 1)]
# comparison, conversion and the boundaries of the machine word
p [(2**70) > (2**69), (2**70) == (2**70), (2**70) <=> (2**69), (2**70).to_s.size]
p [(2**70).to_s(2).size, (2**70).to_s(16), Integer("1" + "0" * 30) + 1]
p [(2**70).even?, (2**70 + 1).odd?, (2**70).bit_length, (-(2**70)).abs == 2**70]
p [(2**70).divmod(7), (-(2**70)).divmod(7), (2**70).gcd(2**35)]
p [Rational(2**70, 2**35), (2**70).to_f, (2**70).to_r == Rational(2**70, 1)]
