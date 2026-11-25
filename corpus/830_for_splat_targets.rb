# A for loop with a splat target collects what each gives as ruby's for
# does: several values as they are, one value as an Array when it converts
# to one, none as []. A splat of an index, an attribute or an ivar, and
# several targets, take the same values apart.
o = Object.new
def o.each
  yield 1, 2
  yield [3, 4]
  yield 5
  yield
  yield [[6]]
  yield nil
end

r = []
for *a in o
  r << a
end
p r, a

r = []
for x, *y in o
  r << [x, y]
end
p r

S = Struct.new(:x)
s = S.new
h = {}
r = []
for *h[:z] in o
  r << h[:z]
end
p r

r = []
for *s.x in o
  r << s.x
end
p r

r = []
for *@iv in o
  r << @iv
end
p r

r = []
for (d, e) in o
  r << [d, e]
end
p r

class Pair
  def to_ary = [7, 8]
end
r = []
for *a in [Pair.new, [Pair.new]]
  r << a.map(&:class)
end
p r

for *n in []
end
p n

def in_method
  for *m in [[1, 2], [3]]
  end
  [m, local_variables]
end
p in_method
