# Block envs are pooled and handed back when the block returns (bench/block_env.sh
# has the numbers). Every way an env can OUTLIVE its block invocation has to keep
# working, and every way a block can leave (normal, break, next, redo, raise,
# return-through) has to hand the env back without disturbing the value.

# 1. a proc made inside a block keeps the block's locals after the block returned
makers = []
3.times { |i| j = i * 10; makers << proc { j += 1; [i, j] } }
p makers.map(&:call)
p makers.map(&:call)

# 2. lambda created in a block, called later, sharing one cell with a sibling
counter = nil; reader = nil
[1].each { |_| n = 0; counter = -> { n += 1 }; reader = -> { n } }
counter.call; counter.call
p reader.call

# 3. nested blocks: inner closure captures both frames; outer keeps running after
acc = []
[1, 2].each { |a| [10, 20].each { |b| acc << -> { a + b } } ; a += 100 }
p acc.map(&:call)

# 4. define_method inside a block captures the block's env
class K
  [:x, :y].each_with_index { |name, idx| define_method(name) { idx * 7 } }
end
p [K.new.x, K.new.y]

# 5. Hash.new with a default block created inside a block
h = nil
[5].each { |base| h = Hash.new { |hh, k| hh[k] = k + base } }
p [h[1], h[2], h]

# 6. Thread.new inside a block reading block locals
r = []
2.times { |i| Thread.new { r << i * 3 }.join }
p r

# 7. external enumerator over a block body
e = [1, 2, 3].each_with_index
p [e.next, e.next, e.next]

# 8. for does not open a scope; a block does
for q in [1, 2]; last_q = q; end
p [q, last_q]
[9].each { |z| inner_only = z }
p defined?(inner_only).inspect

# 9. break / next / redo / raise / return through blocks, then the pool is reused
def through
  [1, 2, 3].each { |v| return v * 100 if v == 2 }
  :unreached
end
p through
p [1, 2, 3].each { |v| break v + 1000 if v == 3 }
p [1, 2, 3].map { |v| next 0 if v == 2; v }
tries = 0
p [1].map { |v| tries += 1; redo if tries < 3; tries }
begin
  [1].each { |v| raise ArgumentError, "from block #{v}" }
rescue ArgumentError => ex
  p ex.message
end
p (1..4).map { |v| v * v }

# 10. deeper than the pool cap: recursion through blocks
def deep(n, &blk) = n == 0 ? blk.call : [n].each { |m| return deep(m - 1, &blk) }
p deep(1500) { :bottom }

# 11. a block's binding
bnd = nil
[42].each { |v| w = v + 1; bnd = binding }
p bnd.local_variable_get(:w)

# 12. lambda called many times: each call gets a fresh frame, closures still fine
l = ->(a) { b = a * 2; -> { b } }
kept = (1..3).map { |i| l.call(i) }
p kept.map(&:call)
p (1..2000).reduce(0) { |s, i| s + l.call(i).call }

# 13. method_missing-style dynamic dispatch inside blocks
class Dyn
  def method_missing(name, *args) = "#{name}:#{args.sum}"
  def respond_to_missing?(*) = true
end
p [1, 2].map { |v| Dyn.new.send(:"m#{v}", v, v) }

# 14. at_exit registered inside a block sees block locals
[7].each { |v| at_exit { puts "exit saw #{v}" } }
puts :done
