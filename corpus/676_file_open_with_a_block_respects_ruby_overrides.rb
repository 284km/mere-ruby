class << File
  alias saved_open open
  def open(*args, **keywords)
    block_given? ? yield([args, keywords]) : [args, keywords]
  end
end
p File.open('not-a-real-file', mode: 'rb')
p File.open('not-a-real-file', mode: 'rb') { |value| value }

class << File
  remove_method :open
  alias open saved_open
  remove_method :saved_open
end
# The restored builtin must still forward the block and close the stream.
path = "/tmp/mere-gem-file-open-override-#{$$}"
File.write(path, 'bytes')
begin
  handle = nil
  p File.open(path) { |io| handle = io; io.read }
  p handle.closed?
ensure
  File.unlink(path)
end
