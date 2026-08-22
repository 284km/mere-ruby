# Integers past the int64 boundary, and containers that contain themselves.
#
# Both were invisible from inside a program that stays small: 123.bit_length
# answered while (2**63).bit_length said "undefined method", and 1 << 64
# returned 0 -- a wrong answer, not an error. A self-referential ARRAY printed
# "[...]" while the same cycle in a HASH ran the stack out.

# --- the boundary itself -------------------------------------------------
puts 1 << 62
puts 1 << 63          # was -9223372036854775808 (sign flip)
puts 1 << 64          # was 0
puts 1 << 100
puts((2**64) >> 3)    # was "type error"
puts((2**64) << 3)
puts(~(2**64))
puts((2**70) >> 70)

# a shift by a negative count is the other direction
puts 5 >> -2
puts 5 << -1

# floor semantics, at both widths
puts(-1 >> 1)
puts((-(2**64)) >> 1)
puts((-(2**64)) / 3)
puts((-(2**64)) % 3)

# --- methods that existed only for the narrow case ----------------------
puts 123.bit_length
puts((2**64).bit_length)
puts((2**64).digits.size)
puts((2**64).digits.first)
puts((2**64).to_r)
puts 3.to_r
puts 0.5.to_r         # a float's EXACT value
puts 1.to_c
puts 123.integer?
puts 1.5.integer?
puts((2**64).integer?)

# round-tripping keeps the value
n = 2**80
puts((n >> 40) << 40 == n)
puts((n << 5) >> 5 == n)

# --- containers that contain themselves ---------------------------------
a = [1]
a << a
p a
p a.hash.class

b = [1]
b << b
p(a <=> b)

h = {}
h[:x] = h
p h

# an array inside a hash is NOT a cycle: the two id spaces are separate, and
# keying the guard on a bare integer used to confuse array 3 with hash 3.
arr = [1, 2]
p [{ k: arr }, arr]

# a cycle that goes through both kinds
h2 = {}
inner = [h2]
h2[:x] = inner
p inner
