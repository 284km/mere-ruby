# A for loop's variable takes what each gives as `|x|` does: an Array whole,
# the first of several values, nil for none. (On the VM it took an Array's
# first element, as `|x,|` does.)
r = []
for x in [[1, 2], [3], nil, [], [[4]]]
  r << x
end
p r
p x

o = Object.new
def o.each
  yield 1, 2
  yield [3, 4]
  yield
  yield [5], 6
end
r = []
for y in o
  r << y
end
p r

r = []
for k in {a: 1, b: [2]}
  r << k
end
p r

def m(xs)
  t = []
  for e in xs
    t << e.class
  end
  [t, e]
end
p m([[1], "s", [2, 3]])

# a block inside the loop sees the variable the loop writes
r = []
for pair in [[1, 2], [3, 4]]
  r << [1].map { |i| pair.sum + i }
end
p r

# the several-targets forms still spread
r = []
for a, b in [[1, 2], 5, [6, 7, 8]]
  r << [a, b]
end
p r

# and the same as a block with one parameter, and one with a trailing comma
p [[1, 2], [3]].map { |v| v }
p [[1, 2], [3]].map { |v,| v }
