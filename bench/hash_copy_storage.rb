mode = ARGV[0] || 'large_replace'
count = Integer(ARGV[1] || '10000')
seed_arg = ARGV.find { |argument| argument.start_with?('--seed=') }
srand(seed_arg ? Integer(seed_arg.split('=', 2).last) : 1)
size = mode == 'small_dup' ? 8 : 676
keys = Array.new(size) { |index| "k#{index}".freeze }
source = keys.each_with_index.to_h
shadow = source.dup
last = shadow
sum = 0

case mode
when 'large_dup', 'small_dup'
  count.times { last = source.dup }
when 'large_replace'
  count.times { last = source.dup.replace(source) }
when 'read'
  count.times { |index| sum += source[keys[index % size]] }
when 'write'
  count.times { |index| source[keys[index % size]] = index }
else
  raise ArgumentError, mode
end
p [mode, count, source.size, last.size, source[keys[0]], last[keys[0]], sum]
