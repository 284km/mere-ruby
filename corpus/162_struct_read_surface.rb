# A Struct's read surface, derived from to_a / to_h.
#
# to_a, values, members, to_h, [] and each were present; size, length,
# values_at, dig, deconstruct_keys and each_pair were not -- part of one
# protocol implemented and the rest never reached for, which is the same shape
# as ENV's missing Hash methods and the numeric tower's missing arms.

S = Struct.new(:a, :b, :c)
s = S.new(1, "two", :three)

p s.size
p s.length
p s.size == s.members.size
p s.values_at(0, 2)
p s.values_at(1)
p s.dig(:a)
p s.dig(:b)
p s.deconstruct_keys([:a, :c])
p s.deconstruct_keys(nil)
p s.deconstruct_keys(nil) == s.to_h
p s.each_pair.to_a
p s.to_a
p s.members

# a longer struct gets them for free -- nothing here is written per member
T = Struct.new(:p, :q, :r, :s, :t)
t = T.new(1, 2, 3, 4, 5)
p t.size
p t.values_at(0, 4)
p t.deconstruct_keys([:t])

# and the pieces stay consistent with each other
p s.each_pair.to_a.map(&:last) == s.to_a
p s.values_at(*(0...s.size).to_a) == s.to_a

# pattern matching uses deconstruct_keys
case s
in { a: 1, c: :three }
  puts "matched"
end
