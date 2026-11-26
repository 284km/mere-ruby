kind = ARGV.fetch(0)
size = Integer(ARGV.fetch(1))
seed = Integer(ARGV.fetch(2, '--seed=1').delete_prefix('--seed='))
srand(seed)
source = if kind == 'hash'
           '{' + size.times.map { |index| "key#{index}:1" }.join(',') + '}'
         elsif kind == 'operators'
           "[\n" + '1+1,' * size + "\n]"
         else
           '[' + '1,' * size + ']'
         end
GC.start
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
value = eval(source, binding, 'large-literal.rb', 1)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
p [kind, size, seed, elapsed, value.length]
