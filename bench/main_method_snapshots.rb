kind = ARGV.fetch(0)
count = Integer(ARGV.fetch(1, '10000'))
seed = ARGV.find { |arg| arg.start_with?('--seed=') }
srand(seed ? Integer(seed.split('=', 2).last) : 1)
def main_snapshot_cost = 7
sum = 0
if kind == 'call'
  captured = method(:main_snapshot_cost)
  count.times { sum += captured.call }
elsif kind == 'capture'
  retained = []
  count.times do |i|
    retained << method(:main_snapshot_cost)
    def main_snapshot_cost = 7
    sum += main_snapshot_cost
  end
  sum += retained.size
else
  raise ArgumentError, kind
end
GC.start
p [kind, count, sum]
