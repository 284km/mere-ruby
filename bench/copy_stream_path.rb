# Compare O2 binaries with a bounded process-family RSS supervisor.
# The sink checks each chunk without retaining the copied file.
require 'tmpdir'
size = Integer(ARGV.fetch(0, '8388608'))
class CopyStreamCounter
  attr_reader :bytes
  def initialize
    @bytes = 0
  end
  def write(chunk)
    raise 'chunk size' unless chunk.bytesize.between?(1, 16384)
    raise 'chunk data' unless chunk == 'x' * chunk.bytesize
    @bytes += chunk.bytesize
    chunk.bytesize
  end
end
Dir.mktmpdir('mere-copy-bench') do |dir|
  path = File.join(dir, 'source')
  File.binwrite(path, 'x' * size)
  GC.start
  sink = CopyStreamCounter.new
  copied = IO.copy_stream(path, sink)
  raise 'byte count' unless copied == size && sink.bytes == size
  puts copied
end
