# The shareable_constant_value magic comment, and the Ractor.shareable? /
# make_shareable it stands on, as test_parse asks

def err(&b)
  b.call
  :ok
rescue Ractor::Error => e
  [e.class, e.message]
end

p [Ractor.shareable?(1), Ractor.shareable?("a"), Ractor.shareable?("a".freeze), Ractor.shareable?(["a"].freeze),
   Ractor.shareable?(Object), Ractor.shareable?(1..2), Ractor.shareable?(Struct.new(:a).new(1).freeze)]
o = Object.new; o.instance_variable_set(:@x, [1]); o.freeze
p Ractor.shareable?(o)
a = [["x"], {"k" => "v"}]
p Ractor.make_shareable(a).equal?(a), a[0][0].frozen?, a[1].keys[0].frozen?, Ractor.shareable?(a)
c = [["y"]]
d = Ractor.make_shareable(c, copy: true)
p d.equal?(c), c.frozen?, d[0][0].frozen?, d == c
o2 = Object.new; def o2.freeze = self
p err { Ractor.make_shareable([o2]) }

# shareable_constant_value: experimental_everything
A = [[1]]
# shareable_constant_value: none
B = [[2]]
# shareable_constant_value: literal
C = [["shareable", "constant#{nil}"], 1..2, :s, nil]
D = A
p [Ractor.shareable?(A), Ractor.shareable?(B), Ractor.shareable?(C), D.equal?(A)]
foo = 1
E = {foo => "bar"}
p E, Ractor.shareable?(E)
F = {"Object" => Object}
p Ractor.shareable?(F)
p err { G = ["Not " + "shareable"] }
p err { var = [:x]; H = var }
p err { I = begin [] end }
p err { J = [[1]].freeze }
K = Class.new
p err { K::L = ["N" + "s"] }
p err { ::M ||= ["N" + "s"] }
p err { K::N ||= ["N" + "s"] }
def kk = K
p err { kk::O ||= ["N" + "s"] }
class X
  # shareable_constant_value: experimental_everything
  var = [[1]]
  P = var
end
Q = []
p [Ractor.shareable?(X::P), Ractor.shareable?(Q)]
# shareable_constant_value: experimental_copy
obj = [["unshareable"]]
R = obj
p [Ractor.shareable?(R), Ractor.shareable?(obj), R == obj, R.equal?(obj)]
# shareable_constant_value: none
S = [1]
p S.frozen?
