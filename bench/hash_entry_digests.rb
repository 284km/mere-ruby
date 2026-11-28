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
elsif mode == 'large_literal'
  hash = eval('{' + count.times.map { |i| "literal_#{i}: 1" }.join(',') + '}')
  sum = hash.size + hash[:literal_0] + hash[("literal_#{count - 1}").to_sym]
elsif ['array_overwrite', 'array_first_overwrite', 'mixed_string_overwrite',
       'mixed_string_read', 'mixed_integer_overwrite', 'plain_string_overwrite'].include?(mode)
  array_keys = mode.start_with?('array_')
  integer_keys = mode == 'mixed_integer_overwrite'
  keys = Array.new(count) { |i| array_keys ? [i] : integer_keys ? i : "entry-#{i}" }
  hash = mode.start_with?('mixed_') ? {[:mutable] => :initial} : {}
  keys.each_with_index { |key, i| hash[key] = i }
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  if mode == 'mixed_string_read'
    keys.each { |key| sum += hash[key.dup] }
  elsif mode == 'array_first_overwrite'
    count.times { |i| hash[keys.first] = i }
  else
    keys.each_with_index { |key, i| hash[key] = i + 1 }
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  if mode == 'array_first_overwrite'
    sum = hash[keys.first]
  elsif mode != 'mixed_string_read'
    sum = hash.values.drop(mode.start_with?('mixed_') ? 1 : 0).sum
  end
  STDERR.puts "loop_seconds=#{elapsed}" if ENV['HASH_ENTRY_LOOP_TIME']
elsif mode == 'mixed_growth' || mode == 'immutable_growth'
  hash = { (mode == 'mixed_growth' ? [] : :immutable) => :initial }
  count.times { |i| hash[i] = i }
  sum = hash.size + hash.fetch(count - 1)
else
  raise ArgumentError, mode
end
GC.start
p [mode, count, sum]
