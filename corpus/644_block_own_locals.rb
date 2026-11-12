# Round 23 of note 545: a name a block assigns before the enclosing scope has
# it is the block's own, as ruby's parse decides -- also when the enclosing
# scope assigns the same name later (it predeclares every name it assigns).
# A read before the block's own assignment still reaches outward, `it` stays
# the implicit parameter, and Binding#local_variables lists the block's own.
x = 1; [1].each { x = 2 }; p x
[1].each { y = 1; [2].each { y = 3 }; p y }
h = {a: (w = 1)}; p w, h
[1].each { z = 1; p binding.local_variable_get(:z) }
[1].each { |a; b| b = a; p b }
q = nil; [1].each { q = 5 }; p q
[1].each do
  k = 1
  [2].each do |v| k += v end
  p k
end
l = lambda { m = 1; m }; m = 9; p l.call, m
def mm; r = proc { n = 1 }; r.call; n = 3; [n, r.call]; end; p mm
eval("[1].each { e1 = 1 }; e1 = 2; p e1")
t = 0; 3.times { |i| t += i }; p t
s1 = proc { u = 1; proc { u += 1; u } }.call; p s1.call, s1.call
c = 0; f = -> { c += 1 }; f.(); p c
[1].each { v1, v2 = 1, 2; p [v1, v2] }; v1 = 0; p v1
pr = proc { x9 = 1 }
x9 = 5
pr.call
p x9
def m9
  q = proc { y9 = 1 }
  y9 = 5
  q.call
  y9
end
p m9
p proc { that = it; it = nil; [that, it] }.call(1)
def prior9 = :method
1.times { r9 = prior9 || (prior9 = :never); p [r9, prior9] }
p proc { inner9 = 2; binding.local_variables }.call.first(1)
