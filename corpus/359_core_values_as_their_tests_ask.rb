# Core values as test_object_id, test_range, test_symbol, test_string and
# test_hash ask (note 383): a class's object_id is its own and a copy's is
# another; Range#step walks an endless range down with a negative step, takes
# a step that is not a Numeric by its own + and <=>, and a Rational range's
# default step is 1; a redefined Range#each gives #to_a and #last(n) their
# elements; an allocated Range survives Marshal uninitialized; a Range
# subclass whose begin is itself compares equal to its twin; `&:sym` hands a
# method's &b the one Proc Symbol#to_proc makes; CP50220/CP50221 encode and
# decode Windows-31J's characters; a symbol key that is not ASCII is quoted
# under an ASCII default; and an object met again in its own #hash is 0.
c = Class.new
p c.object_id == c.object_id, c.object_id == c.dup.object_id, String.object_id == Integer.object_id
a = []; (0...).step(-2) { |x| a << x; break if a.size == 3 }; p a
p (0...).step(-2).take(3)
val = Struct.new(:val) do
  def coerce(num) = [self.class.new(num), self]
  def +(other) = self.class.new(val + other.val)
  def <=>(other) = other.is_a?(self.class) ? val <=> other.val : val <=> other
end
p (0..5).step(val.new(2)).to_a.map { |v| v.is_a?(Integer) ? v : v.val }
p (0.0..5.0).step(val.new(2.0)).to_a.size
a = []; (0r..3r).step { |x| a << x }; p a
p (..10r).step(2r).class
begin
  (0r..10r).step(0) { }
rescue ArgumentError => e
  p e.message
end
r = Marshal.load(Marshal.dump(Range.allocate))
p r.frozen?
r.instance_eval { initialize 5, 6 }
p r, Range.allocate.tap { |x| x.send(:initialize, 1, 2) }.frozen?
class CyclicRange < Range
  def <=>(other) = true
end
x = CyclicRange.allocate; x.send(:initialize, x, 1)
y = CyclicRange.allocate; y.send(:initialize, y, 1)
p x == y, x.eql?(y)
def (obj = Object.new).take_block(&b) = b
p :itself.to_proc.equal?(obj.take_block(&:itself)), lambda(&:upcase).equal?(:upcase.to_proc)
p Class.new { define_method(:k, :class.to_proc) }.instance_method(:k).parameters
begin
  :class.to_proc.call
rescue ArgumentError => e
  p e.message
end
begin
  "foo".match
rescue ArgumentError => e
  p e.message
end
p "\u{ffe2}\u{2235}".encode("CP50220").inspect
p "\u{ffe2}①ｱ".encode("CP50221").bytes, "ｶﾞﾊﾟｱ".encode("CP50220").encode("UTF-8")
p "\u{ffe2}①ｱ".encode("CP50221").encode("UTF-8")
s = Struct.new(:x) { def hash = [x, ""].hash }
a = s.new; b = s.new; a.x = b; b.x = a
p a.hash == b.hash, { a => 1 }[b]
Encoding.default_external = Encoding::US_ASCII
p({ "あ": 1 }.inspect)
