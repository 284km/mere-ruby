# An Enumerator's block-taking Enumerable methods walk #each one element at a
# time, as ruby's do: a block reading $~ sees the match that produced its
# element, and a break ends the walk with its value. Before, the elements were
# collected first, every block saw the LAST match, and a break out of
# String#scan's block or a generator's #each was lost or an error.
e = "wawa".to_enum(:scan, /./)
p e.map { $& }
p e.select { $& == "w" }
p e.reject { $& == "w" }
p e.flat_map { [$&, $&] }
p e.filter_map { $& if $& == "a" }
p e.sort_by { $& }
p e.min_by { $& }
p e.max_by(2) { $& }
p e.minmax_by { $& }
p e.group_by { $& }
p e.partition { $& == "w" }
p e.uniq { $& }
p e.each_with_object([]) { |x, m| m << $& }
p e.inject([]) { |m, x| m << $& }
p e.find { $& == "a" }
p e.find_index { $& == "a" }
p e.take_while { $& == "w" }
p e.drop_while { $& == "w" }
p [e.any? { $& == "a" }, e.all? { $& }, e.none? { $& == "z" }, e.one? { $& == "w" }]
p e.each_entry { }.class
p e.each_with_index.map { |x, i| [$&, i] }
p("wawa".scan(/./) { |x| break x * 2 if x == "a" })
def first_a; "xay".scan(/a/) { |x| return [:returned, x] }; :no; end
p first_a

# a value with several yields, a bare yield, and the two ways enum.c hands them on
o = Object.new
def o.each; yield 1; yield 2, 3; yield [4, 5]; yield; yield 6; end
en = o.to_enum
p en.map { |x| x }
p en.map { |x, y| [x, y] }
p en.select { |x| x }
p en.find_all { |*a| a.size > 1 }
p en.group_by { |x| x.class }
p en.inject { |m, x| [m, x] }
p en.take_while { |x| x }
p en.sort_by { |x| x.to_s }

# Enumerator.new: a break in #each's block is that #each's value, and the
# generator's own loop or rescue does not catch it
g = Enumerator.new { |y| y << 1; y << 2; y << 3; :done }
p g.each { |x| break x * 10 if x == 2 }
p g.each { }
inf = Enumerator.new { |y| n = 0; loop { y << (n += 1) } }
p inf.each { |x| break x if x > 3 }
p inf.find { |x| x * x > 50 }
r = Enumerator.new { |y| begin; y << 1; y << 2; rescue StopIteration; p :caught; ensure; p :ensured; end }
p r.each { |x| break :out }
p g.with_index { |x, i| break [x, i] if i == 1 }
def from_gen; Enumerator.new { |y| y << 1 }.each { |v| return [:r, v] }; :no; end
p from_gen

# a lambda takes a multi-value element apart; each block answers nil to the
# source (take_while stops at once); a lazy to_enum(:with_index) yields two
cond = ->(x, i) { -x }
p [5, 3, 4].each_with_index.min_by(&cond), [5, 3, 4].each_with_index.sort_by(&cond)
sel = proc { |x| x * 2 if x.even? }
p [1, 2, 3, 4].to_enum.to_enum(:take_while).map(&sel).first(2)
p [1, 2, 3, 4].to_enum.to_enum(:drop_while).map(&sel).first(2)
p [1, 2, 3, 4].to_enum.lazy.to_enum(:with_index, 10).map { |x| [x, x * 2] }.first(2)
p [1, 2].each.map { caller_locations(0, 4).map(&:label) }
