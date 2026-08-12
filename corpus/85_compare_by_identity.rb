# Hash#compare_by_identity: lookups compare keys with `equal?`, so two equal
# Strings are two different keys. sidekiq-pro needs it. The hash store is a
# flat [k, v, ...] list, so the flag lives beside the handle and the lookup
# helpers take it -- see KNOWN_GAPS.md for why threading it was the choice.
h = {}.compare_by_identity
a = "x"
b = "x"
h[a] = 1
h[b] = 2
p h.size
p h[a]
p h[b]
p h["x"]
p h.compare_by_identity?
p({}.compare_by_identity?)
p h.key?(a)
p h.key?("x")
p h.fetch(a)
p h.fetch("x", :none)
p h.keys.size
h.delete(a)
p h.size
p h[b]

# symbols and integers are their own identity
g = {}.compare_by_identity
g[:s] = 1
g[:s] = 2
g[7] = 3
g[7] = 4
p g.size
p g[:s]
p g[7]

# an ordinary hash is unaffected
n = {}
n["x"] = 1
n["x"] = 2
p n.size
p n["x"]
p n.compare_by_identity?
