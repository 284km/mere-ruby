require 'zlib'

class Disconnect < StandardError; end

class StreamingSink
  attr_reader :inflated, :writes
  def initialize
    @inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 32)
    @inflated = []
    @writes = 0
  end
  def write(bytes)
    @writes += 1
    @inflated << @inflater.inflate(bytes)
    raise Disconnect, 'client left'
  end
end

sink = StreamingSink.new
writer = Zlib::GzipWriter.new(sink)
writer.mtime = 0
begin
  begin
    writer.write('foo')
    writer.flush
  ensure
    writer.finish
  end
rescue => error
  p [error.class, error.message, sink.inflated.join, sink.writes]
end
