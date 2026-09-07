def try(l)
  p l.call
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 1. a NaN or an infinity has no integer ----------------------------
# Every one of these answered a fabricated machine limit -- and `(-inf).floor`
# answered the POSITIVE one, because the saturation is a property of the cast
# rather than of the question. ruby refuses by name: the message is the value.
%w[to_i to_int truncate round floor ceil].each do |m|
  [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |v|
    begin
      puts "#{v}.#{m} = #{v.send(m).inspect}"
    rescue => e
      puts "#{v}.#{m} ! #{e.class}: #{e.message}"
    end
  end
end
# ...but a DIGIT count above zero has an answer: the receiver itself.
p [Float::NAN.round(2), Float::INFINITY.round(2), Float::NAN.floor(2),
   Float::INFINITY.ceil(2), Float::NAN.truncate(2)]
[-> { Float::NAN.round(-2) }, -> { Float::NAN.round(0) },
 -> { Float::INFINITY.floor(0) }, -> { Float::NAN.divmod(2) },
 -> { Float::NAN.to_r }, -> { Float::INFINITY.to_r },
 -> { Float::NAN.rationalize }, -> { Integer(Float::NAN) }].each { |f| try(f) }
p [Integer(Float::NAN, exception: false), Float::NAN.round(2).nan?,
   1.5.to_i, (-1.5).to_i, 1.5.round, 2.5.round, (-2.5).round]

# ---- 2. a return through a home frame that is gone ---------------------
# `Proc.new { return 42 }` called after its method returned unwound past every
# live frame and came out of the driver as an internal "(unhandled return)".
# It is ruby's LocalJumpError, carrying the value and the reason.
def get_me_a_return
  Proc.new { return 42 }
end
begin
  get_me_a_return.call
rescue LocalJumpError => e
  p [e.message, e.exit_value, e.reason]
end
# ...and `break` next door, which already raised, now carries them too.
begin
  Proc.new { break 1 }.call
rescue LocalJumpError => e
  p [e.message, e.exit_value, e.reason]
end
def yielder
  yield
end
begin
  yielder
rescue LocalJumpError => e
  p [e.message, e.exit_value, e.reason]
end
# a return whose home IS live still returns from it, and a lambda's is its own.
def with_block
  [1].each { return :from_block }
  :not_this
end
def with_lambda
  l = -> { return :from_lambda }
  [l.call, :after]
end
class DefinesOne
  define_method(:m) { return 42 }
  define_method(:n) { |x| return x * 2 }
end
p [with_block, with_lambda, DefinesOne.new.m, DefinesOne.new.n(3),
   -> { return 9 }.call]

# ---- 3. #find re-reads the array's SIZE on every step -------------------
# Walking a snapshot saw all six elements where ruby sees one, and a `break`
# in the block answered the ELEMENT instead of the break's value.
a = [4, 2, 1, 5, 1, 3]
seen = []
a.find { |x| seen << x; a.clear; false }
b = [4, 2, 1, 5, 1, 3]
seen2 = []
b.rfind { |x| seen2 << x; b.clear; false }
c = [1]
seen3 = []
c.find { |x| seen3 << x; c.push(9) if seen3.size < 3; false }
p [seen, seen2, seen3]
p [[1, 2].find { break :x }, [1, 2].rfind { break :y },
   [1, 2, 3].find { |x| x == 2 }, [1, 2, 3].rfind { |x| x < 3 },
   [1, 2, 3].find { false }, [1, 2, 3].find(-> { :none }) { false }]

# ---- 4. the match has to land on a character boundary -------------------
# A byte comparison answered true for a prefix that is part of one character.
s = "\xe3\x81\x82"
p [s.size, s.start_with?("\xe3"), s.end_with?("\x82"), s.end_with?("\x81\x82"),
   s.start_with?(s), s.end_with?(s)]
p ["あい".start_with?("あ"), "あい".end_with?("い"), "あい".start_with?("あい"),
   "\xA9".start_with?("\xA9"), "\xA9".end_with?("\xA9")]
# ...and the check is the ENCODING's: the same bytes tagged BINARY are three
# characters, so the prefix is a whole one.
bin = s.dup.force_encoding("BINARY")
p [bin.size, bin.start_with?("\xe3".dup.force_encoding("BINARY"))]

# ---- 5. a bignum exponent has no answer that fits ----------------------
# `2 ** (2**64)` was Infinity, `1 ** (2**64)` was 1.0 (a Float where ruby
# answers the Integer 1), and `(-1) ** (2**64)` came back a COMPLEX.
p [1 ** (2**64), 0 ** (2**64), (-1) ** (2**64), (-1) ** (2**64 + 1),
   Rational(0) ** (2**64), Rational(1) ** (2**64), Rational(-1) ** (2**64 + 1)]
[-> { 2 ** (2**64) }, -> { 0 ** -(2**64) }, -> { Rational(2) ** (2**64) },
 -> { Rational(0) ** -(2**64) }, -> { Rational(1, 2) ** (2**64) }].each { |f| try(f) }
p [2.0 ** (2**64), 2 ** 64, 2 ** -2, 2 ** 2r, 4 ** (1/2r)]

# ---- 6. the immediates have no singleton table -------------------------
# `def (false).foo` defines a FalseClass INSTANCE method, so
# #singleton_method must still refuse it -- naming the class here found that
# method and answered a Method object.
def (false).foo
  :f
end
p [false.foo, FalseClass.instance_method(:foo).owner, false.singleton_methods]
[-> { false.singleton_method(:foo) }, -> { true.singleton_method(:x) },
 -> { nil.singleton_method(:x) }, -> { 1.singleton_method(:x) }].each { |f| try(f) }
FalseClass.send(:remove_method, :foo)
o = Object.new
def o.own
  :own
end
p [o.singleton_method(:own).call, o.singleton_methods]

# ...and a DEDUPLICATED string cannot carry one either.
[-> { (-"string").singleton_class }, -> { "x".freeze.singleton_class },
 -> { 123.singleton_class }, -> { 3.14.singleton_class },
 -> { :foo.singleton_class }, -> { (2**70).singleton_class }].each { |f| try(f) }
p [nil.singleton_class, true.singleton_class, false.singleton_class,
   "y".dup.freeze.singleton_class.class]

# ---- 7. chunk_while / slice_when need their predicate ------------------
# The Array path refused; an object that includes Enumerable answered an
# ENUMERATOR, which the caller cannot use for anything.
class Numerous
  include Enumerable
  def initialize(*list)
    @list = list
  end

  def each
    @list.each { |i| yield i }
  end
end
n = Numerous.new(1, 2, 4)
[-> { n.chunk_while }, -> { n.slice_when }, -> { [1, 2].chunk_while },
 -> { [1, 2].slice_when }].each { |f| try(f) }
p [n.chunk_while { |a, b| b == a + 1 }.to_a, n.slice_when { |a, b| b != a + 1 }.to_a,
   n.each_entry.to_a, n.chunk { |x| x.even? }.to_a]
