# A Hash emptied from the front (each #shift keeps the rest where it is, and
# #empty? looks only at the first pair), closures whose frames have ended and
# been compacted (they still read and write what they captured, and see each
# other's writes), a FIFO opened from two threads, zip and select handing a
# lambda its values as to a proc, and a core class's own method before a
# module included after it.
h = {}
3000.times { |i| h[i] = [i] }
got = []
got << h.shift until h.empty?
p got.size, got.first, got.last, h, h.size
h = { a: 1, b: 2, c: 3 }
p h.shift, h, h.empty?, h[:c], h.key?(:a)
h[:d] = 4
p h.shift, h.shift, h.shift, h.shift, h

def counter
  n = 0
  [-> { n += 1 }, -> { n }, ->(v) { n = v }]
end
fs = Array.new(200) { counter }
fs.each_with_index { |(inc, _, set), i| set.(i); 3.times { inc.() } }
p fs.map { |_, get, _| get.() }.values_at(0, 1, 199)
mk = ->(s) { t = s * 2; [-> { t }, ->(x) { t << x }] }
pairs = Array.new(100) { |i| mk.("v#{i}") }
pairs[7][1].("!")
p pairs[7][0].(), pairs[8][0].(), pairs.map { |g, _| g.().size }.sum
acc = []
blocks = (1..50).map { |i| proc { acc << i; i * 10 } }
p blocks.sum(&:call), acc.size, acc.last

dir = File.join(Dir.pwd, "fifo498.#{$$}")
Dir.mkdir(dir)
begin
  path = File.join(dir, "f")
  File.mkfifo(path)
  r = Thread.new { open(path, "r") { |io| io.read } }
  w = Thread.new { open(path, "w") { |io| io.write "foo"; io.write "bar" } }
  p r.value, w.value.nil?
  path2 = File.join(dir, "g")
  File.mkfifo(path2)
  w2 = Thread.new { File.open(path2, "w") { |io| io.write "x\ny\n" } }
  r2 = Thread.new { File.open(path2, "r") { |io| io.readlines } }
  p r2.value
  w2.join
ensure
  Dir.children(dir).each { |f| File.delete(File.join(dir, f)) }
  Dir.rmdir(dir)
end

g = Enumerator.new { |y| y.yield 1, 2; y.yield 3, 4 }
out = []
g.zip([7, 8], &->(a, b, c) { out << [a, b, c] })
[1, 2].zip([7], [8], &->(a, b, c) { out << [a, b, c] })
p(([1, 2].zip([7], [8], &->(a, b, c, d) { }) rescue $!.class))
(1..2).zip([7], &->(a) { out << a })
{ k: 1 }.zip([9], &->(a, b) { out << [a, b] })
p out
p %w[a b].each_with_index.select(&->(s, i, z) { z.nil? && i == 1 })
p %w[a b].each_with_index.find(&->(s, i = 5) { i == 0 })

module M
  def to_s = "M"
  def succ = "Msucc"
  def mtag = "tag"
end
Integer.include M
p "#{1}", 1.to_s, 1.succ, 1.mtag, [1].to_s, 2 ** 70 > 0 ? "#{2**70}".size : 0
# (the Method of a value names the core class; a bind names its definition)
p 1.method(:to_s).owner, 1.method(:mtag).owner, M.instance_method(:to_s).bind_call(1),
  Kernel.instance_method(:inspect).bind_call(Class.new(String).new("s")).gsub(/0x\h+/, "")
class Integer
  def to_s(*) = "own"
end
p "#{3}"
