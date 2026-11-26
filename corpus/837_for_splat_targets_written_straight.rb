# A for loop's lone splat target is written straight to: an index, an
# attribute (also through &.) or a constant path gets the Array of what each
# gave, its receiver and arguments evaluated again for every turn.
# (ruby compiles it with no multiple-assignment state: no topn, nothing left
# to pop -- note 552)
class Box837
  attr_reader :log
  def initialize = @log = []
  def []=(*a)
    @log << a
  end

  def x=(v)
    @log << [:x, v]
  end
end
module Holder837; end
o = Object.new
def o.each
  yield 1, 2
  yield [3]
  yield
end

b = Box837.new
calls = 0
key = -> { calls += 1; :k }
for *b[key.()] in o; end
for *b[1, 2] in o; end
for *b.x in o; end
n = nil
for *n&.x in o; end
for *Holder837::K in [[5, 6]]; end
for *::TOP837 in [[7]]; end
p b.log, calls, Holder837::K, TOP837, n

# several targets among which an index or an attribute: the values each gave,
# or the one value as an Array when it converts to one, as for a splat
h = {}
for a, h[:q] in [[1, 2], [3, 4]]; end
p a, h
r = []
for a, h[:q] in o; r << [a, h[:q]]; end
p r
S837 = Struct.new(:x)
s = S837.new
r = []
for f, s.x in o; r << [f, s.x]; end
p r
class Pair837
  def to_ary = [7, 8]
end
for g, h[:w] in [Pair837.new]; end
p [g, h[:w]]
