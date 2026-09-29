# Marshal beyond nil/Integer/String/Array/Hash: objects and their ivars, the
# object table's links, user classes, extended modules, Struct, Range, Class
# and Module, Bignum, marshal_dump / _dump, Rational, Time, exceptions -- the
# bytes are compared with the reference, and every dump is loaded back.
module Tagged; end
class Point
  attr_reader :x, :y
  def initialize(x, y); @x = x; @y = y; end
  def ==(o) = o.is_a?(Point) && o.x == x && o.y == y
end
class Names < Array; end
class Word < String; end
class Box
  attr_reader :v
  def initialize(v); @v = v; end
  def marshal_dump = [:box, @v]
  def marshal_load(a); @v = a[1]; end
end
class Token
  attr_reader :s
  def initialize(s); @s = s; end
  def _dump(_lv) = @s
  def self._load(s) = new(s)
end
Pair = Struct.new(:left, :right)

def show(label, v)
  s = Marshal.dump(v)
  back = Marshal.load(s)
  puts "#{label}: #{s.inspect}"
  puts "  back: #{yield(back)}"
end

pt = Point.new(1, "two")
show(:object, pt) { |b| [b.class, b.x, b.y].inspect }
show(:links, [pt, pt, :sym, :sym]) { |b| [b[0].equal?(b[1]), b[2]].inspect }
show(:user_classes, [Names.new([1, 2]), Word.new("w")]) { |b| b.map(&:class).inspect }
tagged = +"t"
tagged.extend(Tagged)
show(:extended, tagged) { |b| [b, b.is_a?(Tagged)].inspect }
show(:struct, Pair.new(1, [2])) { |b| [b.class, b.to_a].inspect }
show(:ranges, [1..2, 3...4, ("a".."b")]) { |b| b.inspect }
show(:classes, [String, Comparable, Point]) { |b| b.inspect }
show(:bignums, [2**40, -2**70, 2**64]) { |b| b.inspect }
show(:custom, [Box.new(7), Token.new("tok")]) { |b| [b[0].v, b[1].s].inspect }
show(:numbers, [Rational(1, 3), Complex(1, 2), 1.5, -0.0, 1.0e20]) { |b| b.inspect }
show(:times, [Time.at(0).utc, Time.utc(2000, 1, 15, 20, 1, 1, 203)]) { |b| b.map { |t| [t.to_i, t.usec, t.utc?] }.inspect }
e = RuntimeError.new("boom")
e.set_backtrace(["x.rb:1"])
show(:exception, e) { |b| [b.class, b.message, b.backtrace].inspect }
cyc = []
cyc << cyc
show(:cycle, cyc) { |b| b[0].equal?(b).inspect }
h = Hash.new(5)
h[:a] = 1
show(:hash_default, h) { |b| [b, b[:zz]].inspect }

# the refusals, in ruby's words
[-> { Marshal.dump(Class.new.new) }, -> { Marshal.dump(proc {}) },
 -> { Marshal.dump(Hash.new { }) }, -> { Marshal.dump(Module.new) }].each do |pr|
  pr.call
rescue TypeError => err
  puts "refused: #{err.message.sub(/0x\h+/, '0x...')}"
end
p Marshal.load(Marshal.dump([1, "a", :b]), ->(x) { x.is_a?(Integer) ? x * 10 : x })
frozen = Marshal.load(Marshal.dump(["a", ["b"]]), freeze: true)
p [frozen.frozen?, frozen[0].frozen?, frozen[1].frozen?]
