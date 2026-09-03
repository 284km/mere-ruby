# Block envs are pooled, and their lv_up entries are dropped when the block
# returns. The collector must still see everything a closure kept: this program
# forces collections (object pressure between top-level while iterations) while
# procs made inside blocks -- and blocks inside procs -- are still alive.
class Node; attr_accessor :v; def initialize(v) = @v = v; end
keep = []
i = 0
while i < 60
  # 200 objects per iteration: 12k over the loop, well past the 4000-entry trigger
  junk = Array.new(200) { |k| Node.new(k + i) }
  sum = 0
  junk.each { |n| sum += n.v }
  if i % 10 == 0
    # a proc made in a block, capturing the block's env and the loop's locals
    junk.first(2).each_with_index { |n, idx| tag = "#{i}:#{idx}"; keep << proc { [tag, n.v, sum] } }
    # a lambda whose body runs a block that makes another proc
    mk = ->(base) { [base].map { |b| local = b * 2; proc { local + 1 } }.first }
    keep << mk.call(i)
  end
  junk = nil
  i += 1
end
p keep.size
p keep.map(&:call)
# the pool is reused after collections: fresh blocks must not see stale locals
p (1..5).map { |q| [1].each { |r| q += r }; q }
h = Hash.new { |hh, k| hh[k] = k.to_s * 2 }
p [h[1], h[22]]
puts :done
