# Round 22 of note 545 (stage 9): ractors run on the scheduler's threads and
# talk through ports, copy what they are sent, refuse what they may not touch;
# count_objects counts live Arrays and Hashes; undef_method hides an inherited
# method from the listings.
Warning[:experimental] = false

# two ractors and a port: the reader waits while the writers run
port = Ractor::Port.new
rs = 3.times.map { |i| Ractor.new(port, i) { |pt, n| pt << n * 10; n } }
p 3.times.map { port.receive }.sort, rs.map(&:value).sort

# a message is copied (frozen state kept), a shareable one is passed as itself
echo = Ractor.new { Ractor.receive }
s = "mutable"
echo << s
r = echo.value
p r == s, r.equal?(s)
f = Ractor.new([[1]].freeze) { |a| [a.frozen?, a.first.frozen?] }
p f.value

# Ractor.select answers the first port with something in it
p1, p2 = Ractor::Port.new, Ractor::Port.new
Ractor.new(p2) { |pt| pt << :second }
got, v = Ractor.select(p1, p2)
p got.equal?(p2), v

# a raise inside is a RemoteError outside, with the cause
bad = Ractor.new { raise ArgumentError, "inside" }
begin
  bad.value
rescue Ractor::RemoteError => e
  p [e.cause.class, e.cause.message, e.ractor.equal?(bad)]
end

# the block is isolated: no outer locals
outer = 1
begin
  Ractor.new { outer }
rescue ArgumentError => e
  p e.message
end

# what a non-main ractor may not touch
$gv = 1
GREETING = "hello".dup
class Holder; @iv = "str".dup; class << self; attr_reader :iv; end; end
p Ractor.new { begin; $gv; rescue Ractor::IsolationError => iso; iso.message; end }.value
p Ractor.new { begin; GREETING; rescue Ractor::IsolationError => iso; iso.message; end }.value
p Ractor.new { begin; Holder.iv; rescue Ractor::IsolationError => iso; iso.message; end }.value
p Ractor.new { [RUBY_VERSION.frozen?, Encoding::UTF_8.name] }.value

# only one ractor takes a value
src = Ractor.new { :v }
takers = 2.times.map { Ractor.new(src) { |r| begin; r.value; rescue Ractor::Error => err; err.message; end } }
p takers.map(&:value).sort_by(&:to_s)

# monitor: an ended ractor is reported at once, and the answer is false
done = Ractor.new { :ok }
done.join
mp = Ractor::Port.new
p done.monitor(mp), mp.receive

# count_objects counts the live Arrays and Hashes (not its own)
GC.disable
c = {}
ObjectSpace.count_objects(c)
a0, h0 = c[:T_ARRAY], c[:T_HASH]
keep = [[1], [2], {x: 1}]
ObjectSpace.count_objects(c)
p c[:T_ARRAY] - a0 >= 3, c[:T_HASH] - h0 >= 1
GC.enable

# an undef_method in a subclass hides the inherited method
class Base22; def test_a = 1; def test_b = 2; end
class Sub22 < Base22; undef_method :test_a; end
p Sub22.public_instance_methods(true).grep(/^test_/).sort, Sub22.method_defined?(:test_a)
