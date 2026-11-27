kind = ARGV.fetch(0, 'marshal')
iterations = Integer(ARGV.fetch(1, '1000'))
seed = Integer(ARGV.find { |arg| arg.start_with?('--seed=') }.to_s.split('=').last || '1')
srand(seed)
if kind == 'marshal'
  require 'socket'
  bytes = Marshal.dump(Addrinfo.tcp('127.0.0.1', 80))
  object = nil
  iterations.times { object = Marshal.load(bytes) }
  p object.ip_unpack
elsif kind == 'array'
  value = eval('[' + ('1,' * 100_000) + ']')
  p [value.size, value.first, value.last]
elsif kind == 'hash'
  value = eval('{' + 50_000.times.map { |i| "a#{i}: 1" }.join(',') + '}')
  p [value.size, value[:a0], value[:a49999]]
else
  raise ArgumentError, kind
end
