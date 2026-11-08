s = "1" * 100_000
n = s.to_i
t = n.to_s
p [t.length, t == s]
