# Lazy enumerators and Struct's methods as test_lazy_enumerator and
# test_struct ask (note 380): Lazy#each with no block is the lazy itself, and
# with arguments a lazy whose source is walked with them; Lazy#cycle names
# itself and knows its size; an IO is lazy too (its #each is the lines, and
# `each("")` the paragraphs); Lazy#to_enum walks a pipeline method through the
# eager form; and the methods Struct.new writes are Struct's, not the class's.
require "tmpdir"
class Step356
  include Enumerable
  attr_reader :args
  def initialize(r) = @r = r
  def each(*a)
    @args = a
    @r.each { yield _1 }
  end
end
l = (1..3).lazy
p l.each.equal?(l), l.respond_to?(:each)
s = Step356.new(1..3)
p s.lazy.each(4).first, s.args
p l.cycle(3).inspect, l.cycle.inspect, l.cycle(0).size, l.cycle(2).size, l.cycle.size
p l.cycle(2).map {}.inspect, l.cycle(2).map {}.size, l.select {}.cycle(2).size
p 4.times.inject(l) { |e, _| e.cycle(1 << 20) }.size
begin
  Class.new { def each; end; def size = 0; include Enumerable }.new.lazy.cycle("").size
rescue TypeError => e
  p e.message
end
path = File.join(Dir.tmpdir, "lazy356_#{Process.pid}.txt")
File.write(path, "a\nb\n\n\nc\nd\n")
begin
  File.open(path) { |f| p f.lazy.map(&:chomp).first(2) }
  File.open(path) { |f| p f.lazy.each("").map(&:size).to_a }
  File.open(path) do |f|
    lz = f.lazy.each("")
    p lz.to_a
    f.rewind
    p lz.to_a
  end
ensure
  File.delete(path)
end
p (1..3).lazy.to_enum(:each_with_index).map { |a, b| [a, b] }.to_a
p (1..3).lazy.to_enum(:each_slice, 2).to_a, (1..3).lazy.to_enum(:each_with_index) { 3 }.size
lz = [1, 2, 3].lazy
def lz.foo(*args)
  yield args
  yield args
end
e = lz.to_enum(:foo, :hello, :world)
p e.class, e.size, e.to_a
a = []
p (0..Float::INFINITY).lazy.with_index(2, &->(i, j) { a << [i - 1, j] }).take(2).to_a, a
k = Struct.new(:@a)
p k.instance_methods(false).sort
k2 = Struct.new(:a, :b) { def each = 1 }
p k2.instance_methods(false).sort, k2.new(1, 2).to_a, k2.new(1, 2).each, k2.new(3, 4).size
