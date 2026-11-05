# An Enumerator over a source that yields one value an element (Integer#times,
# Array#each, Range#each, String#each_line / each_char / each_byte) walks it
# with a one-parameter block and hands each element on by yield, and is
# materialised without running the source. Neither may change an answer:
# here next to sources that yield several values, a generator, an empty or
# negative count, a lambda, break / next / return / raise in the block, $~
# read in it, and a program that redefines the source.
srcs = [5.times, 0.times, -2.times, [1, [2, 3], nil, "a"].each, [].each, (1..6).each, (1...6).each, (3..1).each,
        "a\nbb\r\nccc\n".each_line, "".each_line, "héllo".each_char, "ab\xff".b.each_byte,
        {a: 1, b: 2}.each, Enumerator.new { |y| y << 1; y.yield 2, 3; y << nil }]
srcs.each do |e|
  p [e.count { |x| x }, e.count { |x, y| y }, e.map { |x| x }, e.map { |x, y| [x, y] }, e.select { |x| x }, e.reject { |x| x },
     e.filter_map { |x| x.to_s if x }, e.collect { |*a| a }, e.find_all { |x| x }, e.filter { |x| !x }]
  p [e.to_a, e.first(2), e.first, e.take(3), e.sum { |x| x.is_a?(Integer) ? x : 0 }, e.min_by { |x| x.to_s }, e.each_slice(2).to_a,
     e.with_index.to_a, e.sort_by(&:to_s), e.include?(2), e.zip(e.to_a), e.each_cons(2).count, e.tally, e.lazy.map { |x| x }.first(2)]
end
p 3.times.map(&->(x) { x * 2 }), [[1, 2]].each.map(&->(x) { x })
r = []
p 3.times.map { |i| r << i; i * 2 }, r
p "a1b2".each_char.select { |c| c =~ /\d/ && $~ }, $~
p [1, 2, 3].each.map { |x| break x * 10 if x == 2; x }
p 4.times.count { |i| next false if i.odd?; true }
def m; 3.times.map { |i| return i if i == 1; i }; end
p m
begin
  3.times.map { |i| raise "x#{i}" if i == 2 }
rescue => e
  p e.message
end
a = [+"x", +"y"]; e = a.each; t = e.to_a; t[0] << "!"; p a, t.equal?(a)
l = +"p\nq"; x = l.each_line.to_a; x[0] << "z"; p l, x
p 3.times.next, [7].each.next, 1_000_000.times.first(3), (1..10**12).each.first(2)
class String
  def lines(*) = ["lines"]
end
p "a\nb".each_line.to_a, "a\nb".each_line.count { true }
class Array
  def each
    yield 1, 2
    self
  end
end
p [9].each.map { |x| x }, [9].each.count { |x, y| y }
