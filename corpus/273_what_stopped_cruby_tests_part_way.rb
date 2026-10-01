# What stopped CRuby's own test files part-way: each of these used to take
# the rest of a file's tests with it.
# (ruby warns, with its own path, that callcc is obsolete; test_hash requires it
# under suppress_warning)
v, $VERBOSE = $VERBOSE, nil
require "continuation"
$VERBOSE = v
p callcc { |c| 1 }, callcc { |c| c.call(2); 3 }, callcc { |c| c.call(4, 5) }, callcc { |c| c.call }
p [1, 2, 3].map { |i| callcc { |c| c.call(i * 10) if i > 1; i } }
# a key that holds itself
h = {}
rec = [h]
h[:x] = rec
obj = Object.new
h2 = {h => obj}
p h2[{x: rec}].equal?(obj), h2[{x: [h]}].equal?(obj), h2[h].equal?(obj)
a = []
a << a
p({a => 1}[a])
# sizes that are counted, not walked
p (1..42).to_a.permutation(30).size, (1..100).to_a.combination(42).size
p (1..42).to_a.repeated_permutation(20).size, (1..59).to_a.repeated_combination(42).size
p [1, 2, 3].permutation(4).size, [].combination(0).size, [:a, :b].repeated_combination(0).size
p 42.upto(Float::INFINITY).size, 1.upto(3.5).size, 5.downto(1.5).size, 5.upto(1).size
p 42.upto(Float::INFINITY).first(2)
# a local the body never reached is nil in its rescue and ensure
def g
  return 1 if true
  u = 5
ensure
  p u
end
g
def k
  raise "x"
  v = 1
rescue
  p [:r, v]
ensure
  p [:e, v]
end
k
x = 9
begin
  raise "y"
  x = 1
rescue
  p x
end
# the program's own p / pp win over Kernel's
class X
  def pp(o) = [:mine, o]
  def p(*a) = :own_p
  def go = [pp(1), p(2)]
end
p X.new.go
"ab" =~ /(a)(b)/
p "#$1 #$2", "#$&", %W[x #$1 y].size
