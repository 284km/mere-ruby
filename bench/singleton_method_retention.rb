# Compare transient objects, literal method bodies and a reused Proc body.
# ruby bench/singleton_method_retention.rb <iterations> <plain|block|proc> --seed=1
count = Integer(ARGV.fetch(0, '20000'))
kind = ARGV.fetch(1, 'block')
seed = Integer(ARGV.fetch(2, '--seed=1').delete_prefix('--seed='))
srand(seed)
body = proc { 1 }
GC.start
count.times do
  object = Object.new
  if kind == 'block'
    object.define_singleton_method(:value) { 1 }
  elsif kind == 'proc'
    object.define_singleton_method(:value, body)
  end
end
GC.start
p [count, kind, seed]
