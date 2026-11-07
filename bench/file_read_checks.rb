# The file's size should not affect read(0), SEEK_SET, or SEEK_CUR.
# foreach also uses zero-byte validation and seeks over read-ahead bytes.
require 'tmpdir'

bytes = Integer(ARGV.fetch(0, '1048576'))
rounds = Integer(ARGV.fetch(1, '1000'))
raise ArgumentError, 'positive size and rounds required' if bytes <= 0 || rounds <= 0

Dir.mktmpdir do |dir|
  path = File.join(dir, 'data')
  line = 'x' * 63 + "\n"
  File.binwrite(path, line * ((bytes + 63) / 64))
  File.open(path, 'rb') do |file|
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rounds.times do
      raise 'nonempty read(0)' unless file.read(0).empty?
      file.seek(32, IO::SEEK_SET)
      file.seek(-16, IO::SEEK_CUR)
    end
    warn "checks seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
    p [rounds, file.pos, file.read(1)]
  end
  count = 0
  total = 0
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  File.foreach(path, mode: 'rb') do |row|
    count += 1
    total += row.bytesize
  end
  warn "foreach seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
  p [count, total]
end
