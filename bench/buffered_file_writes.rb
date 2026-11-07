require 'tmpdir'

count = Integer(ARGV.fetch(0, '16384'))
piece = "aaaa aaaa aaaa aaaa aaaa aaaa aaaa aaaa aaaa aaaa\n"
Dir.mktmpdir do |dir|
  path = File.join(dir, 'data')
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  File.open(path, 'wb') do |file|
    count.times { file.write(piece) }
    file.flush
    p [file.pos, File.size(path)]
  end
  warn "writes=#{count} seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
  p File.binread(path) == piece * count
end
