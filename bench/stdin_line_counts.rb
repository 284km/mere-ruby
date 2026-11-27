kind = ARGV.fetch(0)
count = Integer(ARGV.fetch(1))
seed = ARGV.find { |argument| argument.start_with?('--seed=') }
srand(Integer(seed ? seed.split('=', 2).last : '1'))
bytes = 0
case kind
when 'gets'
  count.times { bytes += STDIN.gets.bytesize }
when 'readlines'
  STDIN.readlines.each { |line| bytes += line.bytesize }
when 'read'
  bytes = STDIN.read.bytesize
else
  raise ArgumentError, kind
end
p [kind, count, bytes, $.]
