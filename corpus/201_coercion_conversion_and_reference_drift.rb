def try(l)
  p l.call
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 1. these methods COERCE; they never ask #to_int --------------------
# divmod and pow were the two names missing from the refusal list, so they
# ANSWERED for an argument they could not read: `1.divmod(nil)` was nil and
# `1.pow(nil)` was 1 -- the receiver handed back as a result.
[-> { 1.divmod(nil) }, -> { 1.divmod("x") }, -> { 1.pow(nil) }, -> { 1.pow("x") },
 -> { 1.0.divmod(nil) }, -> { 1.0.modulo(nil) }, -> { 1.fdiv(nil) },
 -> { 1.remainder(nil) }, -> { 1.quo(nil) }, -> { 1.div(nil) }].each { |f| try(f) }
# a one-argument pow IS `**`, whatever kind of number the exponent is.
p [1.pow(3), 2.pow(1.5), 1.pow(2r), 2.pow(3, 5), (2**70).pow(2, 7), 1.divmod(2r)]
p [4.divmod(1.5), 4.0.divmod(2), 2r.divmod(1r)]

# ...and an object is read through #coerce alone: #to_int does not count, and
# the refusal names the object's OWN class (it used to say "Object").
class WithToInt
  def to_int = 2
end
class WithCoerce
  def coerce(o) = [o, 2]
end
[:div, :divmod, :modulo, :remainder, :quo, :fdiv, :pow, :+, :*].each do |m|
  [WithToInt.new, WithCoerce.new].each do |x|
    begin
      puts "4.#{m}(#{x.class}) = #{4.send(m, x).inspect}"
    rescue => e
      puts "4.#{m}(#{x.class}) ! #{e.class}: #{e.message}"
    end
  end
end

# ---- 2. -0.0 is negative by its SIGN BIT -------------------------------
# `f < 0.0` is false for it, so `(-0.0).arg` answered 0 while
# `(-0.0).to_c.arg` answered pi -- one value, two answers.
p [(-0.0).arg, (-0.0).angle, (-0.0).phase, (-0.0).to_c.arg]
p [(-0.0).abs, (-0.0).magnitude, (-0.0).polar, Complex(-0.0, 0).polar]
p [(0.0).arg, (0.0).polar, (-1.0).arg == Math::PI, (-0.0).to_s]

# ---- 3. the reference moved (ruby 3.2 -> 4.0) ---------------------------
# A one-character range is ONE character now: ruby 3.2 enumerated "a-a" twice,
# and tr's positional pairing is where that shows.
p ["123456789".tr("2-23", "xy"), "123456789".tr_s("2-23", "xy"),
   "hello ^-^".tr("e-", "a-a_"), "hello ^-^".tr("---o", "_a"),
   "hello".tr("e-e", "x"), "abc".tr("a-a", "xy"), "aab".delete("a-a"),
   "abc".count("a-a"), "abc".tr("a-c", "x-z")]
# ...Hash#compact carries the default and the identity flag...
h = Hash.new(1)
h[:a] = nil
p [h.compact.default, Hash.new { 2 }.compact.default_proc.class,
   ({ a: 1 }).compare_by_identity.compact.compare_by_identity?]
# ...`Hash[other]` leaves the identity flag behind...
p [Hash[({ a: 1 }).compare_by_identity].compare_by_identity?,
   Hash[({ a: 1 })], Hash[[[1, 2]]], Hash[1, 2]]
# ...and ruby2_keywords_hash keeps it, for an EMPTY hash too.
p [Hash.ruby2_keywords_hash({}.compare_by_identity).compare_by_identity?,
   Hash.ruby2_keywords_hash({ a: 1 }.compare_by_identity).compare_by_identity?,
   Hash.ruby2_keywords_hash?(Hash.ruby2_keywords_hash({}))]

# ---- 4. Hash.new's capacity: keyword -----------------------------------
# The keywords hash counted as a positional argument, so `Hash.new(capacity:
# 42)` was a hash whose DEFAULT was {capacity: 42}.
p [Hash.new(5, capacity: 42).default, Hash.new(capacity: 42).default,
   (Hash.new(capacity: 42) { 1 }).default_proc.nil?, Hash.new(capacity: -42).size,
   Hash.new({ capacity: 5 }).default]
[-> { Hash.new(unknown: true) }, -> { Hash.new(1, unknown: true) },
 -> { Hash.new(unknown: true) { 0 } }, -> { Hash.new(1, 2) },
 -> { Hash.new(0) { } }].each { |f| try(f) }

# ---- 5. fetch_values without a block raises -----------------------------
# The leaf read each value with hash_get, which answers nil for a missing key.
try -> { { a: 1 }.fetch_values(:a, :b) }
p [{ a: 1 }.fetch_values(:a), { a: 1 }.fetch_values,
   { a: 1 }.fetch_values(:b) { |k| k.to_s }]
begin
  { a: 1 }.fetch_values(:b)
rescue KeyError => e
  p [e.key, e.receiver]
end

# ---- 6. Struct's index is a CONVERSION ---------------------------------
S = Struct.new(:a, :b)
s = S.new(1, 2)
p [s[1.5], s.dig(1.5), s.values_at(1.5)]
p [s.values_at(0..1), s.values_at(0...5), s.values_at(1..), s.values_at(3..4),
   s.values_at(-1..), s.values_at(0, 1..1), s.values_at(..0)]
[-> { s[nil] }, -> { s.dig(nil) }, -> { s[Object.new] },
 -> { s.deconstruct_keys(2) }].each { |f| try(f) }
o = Object.new
def o.to_int = 1
p [s[o], s.dig(o), s.deconstruct_keys(nil), s.deconstruct_keys([:a])]

# ---- 7. one name per receiver in a NameError ----------------------------
# ruby QUOTES the receiver: "for 'false'", not "for false".
[false, true, nil, 1, :s, "s", [], Integer].each do |r|
  begin
    r.singleton_method(:nope)
  rescue NameError => e
    puts e.message
  end
end

# ---- 8. Symbols ---------------------------------------------------------
# `:"..."` escapes are a double-quoted string's: two of them were known and
# every other one lost its backslash, so `:"\0"` was the symbol "0".
p [:"\0", :"\0".length, :"\x01", :"\e", :"a\0b".size, :"a\tb"]
p [:"`", :"`".inspect, :+, :[], :[]=, :+@, :"a b", :"a\nb"]
p [:abcd[1, 2.5], :abcd[1.5], :abcd[1..2], :abcd[-1], :abcd[9]]
p [:abcd.match(/b/, 2), :abcd.match?(/b/, 2), :abcd.match(/b/, 1) ? 1 : 0,
   :abcd.match?(/b/, 99)]
p :upcase.to_proc.parameters

# ---- 9. the LENGTH of a two-argument slice converts too -----------------
# Only an Integer matched, so a Float length looked like NO length: `"abcd"[1,
# 2.5]` answered "b" and `[1, 2, 3][0, 2.5]` answered the ELEMENT 1.
p ["abcd"[1, 2.5], "abcd".slice(1, 2.5), [1, 2, 3][0, 2.5], [1, 2, 3].slice(0, 2.5),
   "abcd".byteslice(1, 2.5), "abcd"[1, o], [1, 2, 3][0, o]]
[-> { [1, 2][0, 2**70] }, -> { "ab"[0, 2**70] }].each { |f| try(f) }

# ---- 10. find's ifnone is CALLED ---------------------------------------
p [[1, 2, 3].find(nil) { false }, [1, 2, 3].find(-> { :none }) { false },
   [1, 2, 3].find { |x| x > 1 }, [1, 2, 3].rfind(-> { :none }) { false }]
[-> { [1, 2, 3].find(42) { false } }, -> { [1, 2, 3].rfind(42) { false } }].each { |f| try(f) }

# ---- 11. flat_map asks #to_ary -----------------------------------------
class ToAry
  def to_ary = [:a, :b]
end
class NilAry
  def to_ary = nil
end
class BadAry
  def to_ary = "array"
end
p [[1, ToAry.new, 2].flat_map { |i| i }, [1, NilAry.new].flat_map { |i| i }.size,
   [[1], [2]].flat_map { |x| x }, [1, [2, [3]]].flat_map { |x| x }]
try -> { [1, BadAry.new].flat_map { |i| i } }

# ---- 12. start_with? / end_with? take several patterns -----------------
# Only the first argument was read, and only as a String.
p ["abc".start_with?("x", "a"), "abc".start_with?(/a/), "abc".start_with?(/b/),
   "abc".start_with?, "abc".end_with?("x", "c"), "abc".end_with?("x")]
p ["abc".start_with?(/a/) ? $~.to_s : nil, ("abc".start_with?(/b/) ; $~).inspect]
class ToStr
  def to_str = "a"
end
p ["abc".start_with?(ToStr.new), "abc".end_with?(ToStr.new),
   "abc".start_with?("a", :y)]
[-> { "abc".start_with?(1) }, -> { "abc".end_with?(:c) },
 -> { "abc".end_with?(/c/) }, -> { "abc".start_with?("x", :y) }].each { |f| try(f) }

# ---- 13. the two negative-size messages --------------------------------
# The flag picked one by "is this max?", which is what neither message
# depends on: Array's blockless min/max name the SIZE and Range's blockless
# ones name the array, so each wore the other's message.
[-> { [1, 2].min(-1) }, -> { [1, 2].max(-1) }, -> { (1..3).min(-1) },
 -> { (1..3).max(-1) }, -> { [1, 2].min(-1) { |a, b| a <=> b } },
 -> { (1..3).max(-1) { |a, b| a <=> b } }, -> { (1..3).max(nil) },
 -> { [1, 2].max(2**70) }].each { |f| try(f) }
p [[1, 2].max(nil), [1, 2].min(nil), [3, 1, 2].max(2), [3, 1, 2].min(2)]
