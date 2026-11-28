mode = ARGV.fetch(0)
count = Integer(ARGV.fetch(1, '10000'))
seed = ARGV.find { |arg| arg.start_with?('--seed=') }
srand(seed ? Integer(seed.split('=', 2).last) : 1)
def match_cost1146(value)
  case value
  in [entry]
    entry
  else
    0
  end
end
sum = 0
if mode == 'pattern'
  count.times { sum += match_cost1146([7]) }
elsif mode == 'array'
  result = [
    *Array.new(100000, 7)
  ]
  sum = result.size + result.last
elsif mode == 'plain'
  count.times { sum += 7 }
else
  raise ArgumentError, mode
end
GC.start
p [mode, count, sum]
