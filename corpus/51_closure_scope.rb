# Block scoping and closure lifetime.

# 1. a lambda made inside a block keeps the block param after the block ends
f = nil
[7].each { |a| f = lambda { a } }
p f.call

# 2. one binding per iteration
fs = []
[1, 2, 3].each { |a| fs << lambda { a } }
p fs.map(&:call)

# 3. a local first assigned inside the block also survives capture
g = nil
[1].each { x = 42; g = lambda { x } }
p g.call

# 4. reassigning the param after the capture is visible (shared cell, not a snapshot)
h = nil
[1].each { |a| h = lambda { a }; a = 99 }
p h.call

# 5. an outer local stays shared: assigning outside is visible inside the closure
x = 1
k = nil
[1].each { k = lambda { x } }
x = 2
p k.call

# 6. assigning an existing outer local from inside a block persists after it
y = 1
[1].each { y = 5 }
p y

# 7. a block-local does not leak to the enclosing scope
[1].each { zz = 5 }
p defined?(zz)

# 8. a block param does not clobber a same-named outer local
a = 1
[9].each { |a| a + 1 }
p a

# 9. nested blocks each capture their own binding
outer = []
[1, 2].each { |i| [10, 20].each { |j| outer << lambda { i * j } } }
p outer.map(&:call)

# 10. a closure can still write through to an outer local after the block ends
n = 0
inc = nil
[1].each { inc = lambda { n += 1 } }
inc.call
inc.call
p n

# 11. `for` does not introduce a scope: its variable leaks (unlike a block)
for i in 1..3
end
p i

# 12. while/if bodies are not scopes either
if true
  w = 3
end
p w

# 13. define_method in a loop captures each name (rainbow's refinement pattern)
class Holder
  [:one, :two].each do |m|
    define_method(m) { m.to_s }
  end
end
p Holder.new.one, Holder.new.two

# 14. a proc capturing a method local outlives the method
def make_counter
  c = 0
  [nil].each { }
  lambda { c += 1 }
end
ctr = make_counter
ctr.call
p ctr.call

# 15. block-locals are fresh per invocation, not carried across
seen = []
2.times { |i| v = (i + 1) * 10; seen << v }
p seen

# 16. explicit block-local (`|x; t|`) shadows and does not leak
t = "outer"
[1].each { |x; t| t = "inner" }
p t
