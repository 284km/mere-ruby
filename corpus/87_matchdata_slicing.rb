# MatchData#[] takes the Array forms, not just a single index: (start, length),
# a Range, and a negative index counting from the end of the group list.
m = "a1b2".match(/(\d)(\w)(\d)/)
p m[0]
p m[1]
p m[1, 2]
p m[0, 2]
p m[1..2]
p m[1...3]
p m[-1]
p m[-2]
p m[9]
p m[1, 99]
p m[9, 1]
p m.to_a
p m.captures
p m.values_at(1, 3)
p m.values_at(0, 9)
p m.size
p m.length

n = "x".match(/(a)?(x)/)
p n[1]
p n.to_a
p n[0, 3]
p n.values_at(1, 2)
