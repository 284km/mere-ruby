# A Range holds its bounds as VALUES, not as two integers: the integer range
# is only the common one.
p [("a".."e").class, (1.0..2.0).class, (1..).class, (..5).class]
p [("a".."e").begin, ("a".."e").end, (1..).end, (..5).begin]
p [("a".."e").to_a, ("a"..."e").to_a, ("aa".."ad").to_a]
p [("a".."e").min, ("a".."e").max, ("a".."e").count, ("a".."e").include?("c")]
p ("a".."d").map { |s| s.upcase }
p ("a".."z").cover?("mm")          # true: cover? compares, include? enumerates
p [(1.0..2.0).include?(1.5), (1.0..2.0).cover?(2.0), (1.0...2.0).cover?(2.0)]
p [(1..5) === 3, ("a".."z") === "q", (1..) === 1000, (..5) === 2]
case "q" when "a".."z" then p :letters end

# A Range is frozen, and its bounds are whatever was written -- no coercion.
p [(1..5).frozen?, ("a".."e").frozen?]
p [(1..5).begin.class, (1.0..2.0).begin.class, ("a".."e").begin.class]

# An OPEN range never materialises: `(1..)` and `(1..Float::INFINITY)` are
# both unbounded above, and iterating them runs until the block breaks.
r = []
(1..).each do |i|
  break if i > 3
  r << i
end
p r
p [(1..).first(3), (1..).take(3), (1..).first, ("a"..).first(3)]
p [(1..Float::INFINITY).first(3), (1..Float::INFINITY).max]
p (1..Float::INFINITY).lazy.map { |x| x * 2 }.first(3)
p [(1..).size, (..5).size, (1..Float::INFINITY).size, (1...9).size]

# ...and what would need every element says so, rather than answering [].
def err
  yield
rescue => e
  [e.class, e.message]
end
p err { (1..).to_a }
p err { (1..).max }
p err { (1..).last }
p err { (..5).min }
p err { (..5).first }
p err { (..5).each { } }
p err { (1..5).each_entry.to_a.size }
