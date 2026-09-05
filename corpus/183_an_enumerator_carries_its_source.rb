# `enum.with_index { ... }` does not materialise the elements and run the source
# method again over pairs: it calls the source ONCE with the block wrapped in an
# index counter. The difference is invisible for map and select and decisive for
# every source that decides how far to walk from the block's own value -- which
# is how rubygems 4 orders platform matches (`matching.sort_by.with_index`), and
# how bundler 4 came to call LazySpecification's methods on an Array.

src = [30, 10, 20]

# sources that answer the block's values
p src.map.with_index { |x, i| [x, i] }
p src.flat_map.with_index { |x, i| [x, i] }
p src.filter_map.with_index { |x, i| i.zero? ? nil : x }
p src.each_with_index.map { |x, i| [x, i] }

# sources that answer ELEMENTS: the pairing must not reach the caller
p src.sort_by.with_index { |x, i| [x, i] }
p src.sort_by.with_index { |x, i| -x }
p src.min_by.with_index { |x, i| x }, src.max_by.with_index { |x, i| x }
p src.minmax_by.with_index { |x, i| x }
p src.group_by.with_index { |x, i| i.even? }
p src.partition.with_index { |x, i| i > 0 }
p src.each_entry.with_index { |x, i| x }
p src.uniq

# sources that STOP on the block's value: the walk is the caller's, not a
# materialising one
p src.find.with_index { |x, i| i > 0 }
p src.detect.with_index { |x, i| x < 20 }
p src.find_index.with_index { |x, i| i > 0 }
p src.take_while.with_index { |x, i| i < 2 }
p src.drop_while.with_index { |x, i| i < 2 }
p src.select.with_index { |x, i| i > 0 }
p src.reject.with_index { |x, i| i > 0 }

# the index starts where it is told to, and the source keeps its own arguments
p src.each.with_index(1) { |x, i| [x, i] }
p src.map.with_index(10) { |x, i| [x, i] }
p src.each_with_object([]).with_index { |(x, acc), i| acc << [x, i] }
p [1, 2, 3].each_slice(2).with_index { |s, i| [s, i] }
p({ a: 1, b: 2 }.map.with_index { |(k, v), i| [k, v, i] })
p [[1, 2], [3, 4]].each.with_index { |(a, b), i| [a, b, i] }

# `each` answers its receiver. (A `break` inside a with_index block does NOT
# leave the walk here -- the wrapper reaches the caller's block through a Proc,
# and a break there becomes that call's value. Recorded in KNOWN_GAPS.md.)
p src.each.with_index { |x, i| x }

# materialising an enumerator drives its source with a block that answers nil,
# so a search walks all of it and a take_while stops at the first element
p src.find.to_a, src.detect.to_a, src.sort_by.to_a, src.group_by.to_a
p src.take_while.to_a, src.drop_while.to_a, src.select.to_a
p src.each_slice(2).to_a, src.each_cons(2).to_a, src.each_with_object([]).to_a

# ...which is legal only because a nil key compares with a nil key
p(nil <=> nil, [nil, nil].sort, [3, 1, 2].sort_by { nil })
p(true <=> true, [true, true].sort, [false, false].sort)
begin
  [nil, 1].sort
rescue ArgumentError => e
  p e.message
end
begin
  [true, false].sort
rescue ArgumentError => e
  p e.message
end

# a generator has no source method to call again, and answers the same way
gen = Enumerator.new { |y| y << 30 << 10; y.yield 20 }
p gen.to_a, gen.with_index { |x, i| [x, i] }, gen.sort_by.with_index { |x, i| x }
inf = Enumerator.new { |y| i = 0; loop { y << (i += 1) } }
p inf.first(3), inf.take(2), inf.lazy.map { |x| x * 2 }.first(2)
p Enumerator.produce(1) { |x| x * 3 }.first(4)

# the receiver of an undefined method is named by VALUE when it is one of the
# three singletons, and by class otherwise
[-> { nil.no_such }, -> { true.no_such }, -> { false.no_such },
 -> { 1.no_such }, -> { :s.no_such }, -> { "s".no_such }, -> { Object.new.no_such },
 -> { nil.send(:no_such) }, -> { nil.instance_variable_get("@a").no_such }].each do |f|
  begin
    f.call
  rescue NoMethodError => e
    puts e.message
  end
end
class Priv
  private def hidden; end
end
begin
  Priv.new.hidden
rescue NoMethodError => e
  puts e.message
end
