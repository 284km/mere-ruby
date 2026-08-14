# An Enumerator built by `to_enum` remembers the arguments it was given and
# drives its method the way `send` does (so a private one still runs), and a
# Range answers about its own endpoints without materialising itself.

class Walker
  def pairs(a, b)
    return to_enum(:pairs, a, b) unless block_given?
    a.each { |x| b.each { |y| yield [x, y] } }
  end

  def public_each(enum, &block)
    hidden(enum, &block)
  end

  def enum_of(enum)
    hidden(enum)
  end

  private

  def hidden(enum)
    return to_enum(__method__, enum) unless block_given?
    enum.map { |x| yield x }
  end
end

w = Walker.new
p w.pairs([1, 2], [:a]).to_a
p w.pairs([1], [:a, :b]).map { |x| x }
p w.public_each([1, 2]) { |x| x * 2 }
e = w.enum_of([1, 2, 3])
p e.class
p e.to_a
p e.map { |x| x * 10 }
p e.first(2)

def top_pairs(a)
  return to_enum(:top_pairs, a) unless block_given?
  a.each { |x| yield x }
end
p top_pairs([4, 5]).to_a

# the builtin enumerators still behave
p [1, 2, 3].each_slice(2).to_a
p %w[a b].each_with_index.to_a
p [3, 1].each_entry.to_a

# Range: the endpoints as written
r = (1..5)
x = (1...5)
p [r.begin, r.end, r.exclude_end?]
p [x.begin, x.end, x.exclude_end?]
p [r.first, r.last, r.min, r.max, r.size, r.count]
p [x.first, x.last, x.min, x.max, x.size, x.count]
p [x.first(2), x.last(2), r.last(2)]
p [r.include?(5), x.include?(5), r.cover?(0), x.cover?(4)]
p r.to_a
p r.respond_to?(:begin)
p Range.instance_method(:begin).owner
last = (0..0)
p [(1..2), (3..4)].map { |q| last = last.begin + q.begin..last.max + q.max }

# min / max come from the endpoints, so they must not enumerate: an endless
# range would never finish. (What `end` reports for one is a known gap.)
p [(1..5).min, (1..5).max, (1...5).min, (1...5).max]
p [(5..1).min, (5..1).max, (1..1).min, (1...1).max]
p [(1..5).min(2), (1..5).max(2)]
endless = (1..Float::INFINITY)
p endless.begin
p endless.include?(10**9)
p endless.cover?(0)

# An operator written as a METHOD is the operator, and the named forms are the
# same arithmetic: `10.%(3)` and `10.modulo(3)` are `10 % 3`.
p [10.%(3), 6543.21.%(137), 1.+(2), 7./(2), 2.**(10), 5.<=>(3), 1.<(2)]
p [10.modulo(3), 10.div(3), 10.fdiv(4), 10.remainder(3), (-7).remainder(3), (-7).div(3)]
# Float#% is floored, like Integer#%: the sign follows the divisor
p [6543.21 % 137, 7.5 % 2, -7.5 % 2, -7 % 3, 7 % -3]

# Float#next_float / #prev_float step by one ulp. (There is no way to look at
# a float's bits here, so the step is found by doubling and halving until the
# sum changes -- which lands on exactly the same value.)
p [1.0.next_float, 1.0.prev_float, 2.0.next_float, 0.5.prev_float]
p [1.0.next_float > 1.0, 1.0.prev_float < 1.0, 1e10.next_float > 1e10]
p [(1.0.next_float - 1.0) > 0, 1.0.next_float.prev_float == 1.0]

# object_id is stable per object, and equal values that ARE the same object
# (integers, symbols, nil) answer the same id
o1 = Object.new
o2 = Object.new
p [o1.object_id == o1.object_id, o1.object_id == o2.object_id]
p [1.object_id == 1.object_id, :sym.object_id == :sym.object_id]
p [nil.object_id == nil.object_id, true.object_id == true.object_id]
p [o1.object_id.class, 1.object_id.class]
s1 = "a"
p s1.object_id == s1.object_id
