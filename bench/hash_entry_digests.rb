mode = ARGV.fetch(0, 'churn')
count = Integer(ARGV.fetch(1, '10000'))
seed = ARGV.find { |arg| arg.start_with?('--seed=') }
srand(seed ? Integer(seed.split('=', 2).last) : 1)
sum = 0
if mode == 'churn'
  count.times do |i|
    key = [i]
    hash = {key => i}
    copy = hash.dup
    sum += copy[key]
    key << :changed
    # Small CRuby tables compare an eight-bit hash hint before identity;
    # a mutated identical key can still hit by chance. Exercise both reads
    # without assuming that every mutation changes that hint.
    hash[key]
    copy[key]
  end
elsif mode == 'mutable_read'
  key = [1, 2]
  hash = {key => 7}
  count.times { sum += hash[key] }
else
  raise ArgumentError, mode
end
GC.start
p [mode, count, sum]
