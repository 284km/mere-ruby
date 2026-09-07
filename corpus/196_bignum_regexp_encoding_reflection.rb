# Three things this program pins. The first group is the dangerous one: every
# line in it used to produce a NUMBER, and the number was wrong.

# ---- 1. integers -----------------------------------------------------------
B = 2**70

# a zero divisor is a refusal, not a quotient. The long-division loop asks "how
# many times does the divisor go into this prefix", and for zero the answer is
# 9 at every digit -- so this used to answer 9999999999999999999999.
[-> { B.div(0) }, -> { B.divmod(0) }, -> { B % 0 }, -> { B.modulo(0) },
 -> { 5.div(0) }, -> { B / 0 }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end

# Integer#[] reads the TWO'S-COMPLEMENT bit, so the shift is arithmetic: C
# division truncates toward zero, which is not a shift for a negative receiver.
p [(-5)[0], (-5)[1], (-5)[2], (-5)[3], (-1)[0], (-1)[99]]
p [255[0, 4], (-5)[0, 3], (-8)[1..3], 5[0..1]]
# ...and a bignum has bits too (this was a NoMethodError)
p [(2**70)[70], (2**70)[69], (2**70 + 1)[0], (-(2**70))[0], (-(2**70) - 1)[0]]

# modular exponentiation FLOORS, like Ruby's %, so the result takes the
# modulus's sign; and it squares rather than stepping once per unit.
p [(-2).pow(3, 5), 2.pow(10, 1000), (-2).pow(2, 5), 2.pow(0, 7), 3.pow(100, 7)]

# `send(:-@)` is the same method as the operator, and it negates. The primitive
# arm answered the receiver, so `2.send(:-@)` was 2.
p [2.send(:-@), (-8).send(:-@), (2**64).send(:-@), 1.5.send(:-@),
   Rational(1, 2).send(:-@), "x".send(:-@).frozen?]

# fdiv between two bignums divides in DECIMAL: to_f on each side first is
# Inf/Inf = NaN once both overflow a double.
p [(10**400).fdiv(10**397), (10**20).fdiv(10**18), (-10**400).fdiv(10**397),
   2.fdiv(10**400), (10**400).fdiv(2)]

# an integer square root is an INTEGER operation
p [Integer.sqrt(10**12), Integer.sqrt(2**80), Integer.sqrt(10**56), Integer.sqrt(0),
   Integer.sqrt(9), Integer.sqrt(8), Integer.sqrt(9.5)]
begin
  Integer.sqrt(-1)
rescue => e
  puts "#{e.class}: #{e.message}"
end
begin
  Integer.sqrt("x")
rescue => e
  puts "#{e.class}: #{e.message}"
end

# the four ordering operators run the coerce protocol, exactly as <=> does
class Half
  def coerce(other) = [other.to_f, 1.0]
end
p [1 > Half.new, 1 < Half.new, 0 >= Half.new, B > Half.new, B <=> Half.new]

# a precision that does not fit is refused rather than rounded to
[-> { 42.round(-(2**64)) }, -> { 42.round(Float::INFINITY) },
 -> { 42.round(1 << 31) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end

# zero has nothing to shift, so no width is too big for it
p [0 << (2**70), 0 >> (2**70), 1 >> (2**70), 1 << (-(2**70))]

# a #to_int that does not answer with an Integer has not converted anything
class Fake
  def to_int = "not an integer"
end
begin
  Integer.try_convert(Fake.new)
rescue => e
  puts "#{e.class}: #{e.message}"
end
p [Integer.try_convert(3), Integer.try_convert(Object.new)]

# ---- 2. a pattern carries an encoding --------------------------------------
# ...and it can name a non-ASCII character in three ways: a raw byte, a \u
# escape, or a \x escape. Only the raw bytes were being looked at.
def enc(r) = [r.encoding.to_s, r.fixed_encoding?, r.source.encoding.to_s]
p enc(/abc/)
p enc(/abc/n)
p enc(/abc/u)
p enc(/abc/e)
p enc(/abc/s)
p enc(/\u{3042}/)
p enc(/\u{41}/)
p enc(/\xe3\x81\x82/)
p enc(/\x41/)
p enc(/あ/)
p enc(Regexp.new("abc"))
p enc(Regexp.new("\u{3042}"))
p enc(Regexp.new("\\u{3042}"))
p enc(Regexp.new("abc", Regexp::NOENCODING))

p [Regexp.quote("abc").encoding.to_s, Regexp.quote("\u{3042}").encoding.to_s]
p Regexp.union("abc").source, Regexp.union.source

# try_convert is a door for a program's own classes, and it was nailed shut
class Patternish
  def to_regexp = /xy/
end
p Regexp.try_convert(Patternish.new)
p Regexp.try_convert(/z/), Regexp.try_convert("no"), Regexp.try_convert(Object.new)
class BadPattern
  def to_regexp = 42
end
begin
  Regexp.try_convert(BadPattern.new)
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 3. reflection ---------------------------------------------------------
# a Method reached through method_missing is owned by the receiver's CLASS
class Ghostly
  def respond_to_missing?(name, priv = false) = true
  def method_missing(name, *args) = :answered
end
p Ghostly.new.method(:anything).owner
p Ghostly.new.method(:anything).call
p Ghostly.new.method(:anything).name

# an explicit-but-empty `||` is not a parameter; the sentinel that marks it is
# this interpreter's bookkeeping and has no business in a program's output
k = Class.new { define_method(:none) { || :ok } }
p k.instance_method(:none).parameters
p k.new.none
p k.instance_method(:none).arity

# a lambda is strict about its count, and curry's argument IS that count
def two(a, b) = [a, b]
p method(:two).curry(2)[1][2]
[-> { method(:two).curry(3) }, -> { method(:two).curry(1) },
 -> { ->(a, b) {}.curry(3) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
# ...a non-lambda proc is not strict, and a variadic lambda has no fixed count
p proc { |a, b| [a, b] }.curry(3)[1][2][3]
def rest(*a) = a
p method(:rest).curry(3)[1][2][3]
