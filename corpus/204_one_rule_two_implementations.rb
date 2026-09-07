def try(l)
  p l.call
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 1. a Hash answers Enumerable over its PAIRS ------------------------
# Only the BLOCK-taking path converted the hash, so `h.min { }` worked and
# `h.min` was a NoMethodError -- the same name, answered or not depending on
# whether a block came with it. The list was measured, not guessed.
h = { a: 1, b: 2 }
p [h.one?(Object), h.one?(Array), h.first, h.min, h.max, h.minmax]
p [h.sum([]), h.tally, h.uniq, h.take(1), h.drop(1), h.zip([1, 2])]
p [h.grep(Array).size, h.grep_v(Array).size, h.inject { |a, _| a }]
p [h.each_slice(1).to_a, h.each_cons(1).to_a, h.cycle(1).to_a]
# ...and the enumerator forms keep the HASH as the receiver they print.
p [h.each_slice(1).inspect, h.cycle(2).inspect, h.find_index.inspect]
p [({}).one?(NilClass), ({}).first, ({}).min, ({ x: 9 }).find_index { |k, v| v == 9 }]

# ---- 2. one rule, two implementations ----------------------------------
# flat_map is written twice: the interpreter's walk (Array / Range / Hash) and
# the prelude's Enumerable#flat_map (every other Enumerable). A nil #to_ary
# means "append it as it is" -- fixed in the first and still refused by the
# second, so the same element in the same position answered two ways.
class ToAry204
  def to_ary = [:a, :b]
end
class NilAry204
  def to_ary = nil
end
class BadAry204
  def to_ary = "array"
end
class Numerous204
  include Enumerable
  def initialize(*list)
    @list = list
  end

  def each
    @list.each { |i| yield i }
  end
end
[[1, ToAry204.new, 2], Numerous204.new(1, ToAry204.new, 2)].each do |r|
  p r.flat_map { |i| i }
end
p [[1, NilAry204.new].flat_map { |i| i }.size,
   Numerous204.new(1, NilAry204.new).flat_map { |i| i }.size,
   Numerous204.new(1, NilAry204.new).collect_concat { |i| i }.size]
[-> { [1, BadAry204.new].flat_map { |i| i } },
 -> { Numerous204.new(1, BadAry204.new).flat_map { |i| i } }].each { |f| try(f) }

# ...and #zip converts through #to_enum(:each), not #to_a: an object that only
# CLAIMS #each and answers to_enum was sent to_a.
class Claims204
  attr_reader :called
  def initialize(d) = @d = d
  def to_enum(sym) = (@called = :to_enum; @d.to_enum(sym))
  def respond_to_missing?(*args) = @d.respond_to?(*args)
end
c = Claims204.new(4..6)
p [Numerous204.new(1, 2, 3).zip(c), c.called]
p [Numerous204.new(1, 2).zip([3, 4]), [1, 2].zip([3, 4])]
try -> { Numerous204.new(1, 2).zip(Object.new) }

# ...and #sort's comparator block, which the Array receiver answered and an
# Enumerable collected into an array did not.
p [Numerous204.new(3, 1, 2).sort { |a, b| b <=> a },
   Numerous204.new(3, 1, 2).sort,
   [3, 1, 2].sort { |a, b| b <=> a }]

# ---- 3. inject's operator may be a String, or convert to one ------------
class OpStr204
  def to_str = "+"
end
p [[1, 2, 3].inject(:+), [1, 2, 3].inject("+"), [1, 2, 3].inject(10, :-),
   [1, 2, 3].inject(10, "-"), [1, 2].inject(OpStr204.new),
   [1, 2].inject(10, OpStr204.new), Numerous204.new(1, 2, 3).inject(10, "-")]
# (the refusal names the VALUE, whose inspect carries an address -- so only
#  its shape is compared here.)
[-> { [1, 2].inject(Object.new) }, -> { [1, 2].inject(10, Object.new) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message.sub(/0x[0-9a-f]+/, "0xADDR")}"
  end
end

# ---- 4. an alias in a subclass may name an INHERITED method ------------
# Only this class's table was read, so an inherited source looked like a
# BUILTIN and the alias delegated to a primitive that does not exist.
class Parent204
  def pub = :from_parent
end
class Child204 < Parent204
  alias aliased pub
  alias_method :aliased2, :pub
end
p [Child204.new.aliased, Child204.new.aliased2,
   Child204.instance_methods(false).sort,
   Child204.new.method(:aliased).class,
   Child204.instance_method(:aliased).original_name]

# ---- 5. Kernel#method includes the PRIVATE ones -----------------------
# respond_to_missing? is asked with the flag TRUE, and the refusal names the
# CLASS ("for class 'C'") -- not the "for an instance of" a failed call reports.
class Claims205
  def respond_to_missing?(m, priv = false)
    case m
    when :handled_publicly then true
    when :handled_privately then priv
    else false
    end
  end

  def method_missing(m, *a) = :mm
end
o = Claims205.new
p [o.method(:handled_publicly).class, o.method(:handled_privately).class,
   o.method(:handled_publicly).call]
[-> { o.method(:not_handled) }, -> { 1.method(:nope) },
 -> { Object.new.method(:nope) }].each { |f| try(f) }

# ---- 6. Kernel#lambda / #proc / #loop are sendable --------------------
# They were only reachable as a bare call with a literal block, so dispatching
# them BY NAME answered "undefined method 'lambda'".
p [send(:lambda) { 42 }.lambda?, send(:proc) { 42 }.lambda?,
   __send__(:lambda) { 42 }.call, send(:loop) { break :stopped }]
class Sends204
  def make = [send(:lambda) { 1 }.lambda?, send(:proc) { 2 }.lambda?, send(:loop) { break 3 }]
end
p Sends204.new.make

# ---- 7. rand ignores the SIGN of its argument ------------------------
srand(99)
p [rand(-3).class, rand(-1.5).class, rand(0).class, rand(-0.0).class,
   20.times.map { rand(-3) }.all? { |v| v >= 0 && v < 3 },
   20.times.map { rand(-1.5) }.all? { |v| v == 0 }]

# ---- 8. an exception copies its state ---------------------------------
# `#exception(msg)` is a COPY with a new message, "without reinitializing":
# building a fresh instance dropped what the exception's own initialize put
# there.
class Custom204 < StandardError
  attr_reader :val
  def initialize(val)
    @val = val
    super()
  end
end
e = Custom204.new(:boom)
e2 = e.exception("message")
p [e2.class, e2.val, e2.message, e.exception.equal?(e), e2.equal?(e)]
# ...and a pair-shaped exception can be given a backtrace.
begin
  raise
rescue RuntimeError => err
  bt = err.backtrace
  p [err.dup.backtrace.equal?(bt), bt.class]
  err.set_backtrace(["hi:1:in 'x'"])
  p [err.backtrace, err.dup.backtrace]
end

# ---- 9. the location argument is PRINTED ------------------------------
p [SystemCallError.new("foo", 1, :not_a_string).message,
   SystemCallError.new("foo", 2, 5).message,
   SystemCallError.new("foo", 999).message,
   SystemCallError.new("foo").message,
   SystemCallError.instance_method(:initialize).arity]

# ---- 10. a hex float needs no exponent -------------------------------
# ruby 3.2's strtod read a hex fraction only together with a p exponent.
p [Float("0x0.8"), Float("0x1.8"), Float("0x0.8p1"), Float("0x1f"), Float("0x1_f")]
[-> { Float("0x") }, -> { Float("0x.") }, -> { Float("0x1__0") }].each { |f| try(f) }
