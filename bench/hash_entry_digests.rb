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
elsif mode == 'mutable_write'
  key = [1, 2]
  hash = {key => 7}
  count.times { |i| hash[key] = i }
  sum = hash[key]
elsif mode == 'hash_key_read'
  key = {a: 1, b: 2}
  hash = {key => 7}
  count.times { sum += hash[key] }
elsif mode == 'mixed_growth' || mode == 'immutable_growth'
  hash = { (mode == 'mixed_growth' ? [] : :immutable) => :initial }
  count.times { |i| hash[i] = i }
  sum = hash.size + hash.fetch(count - 1)
else
  raise ArgumentError, mode
end
GC.start
p [mode, count, sum]
