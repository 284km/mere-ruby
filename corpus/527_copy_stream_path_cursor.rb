require 'tmpdir'
require 'pathname'
require 'stringio'

class CursorCopySink
  attr_reader :data, :sizes
  def initialize
    @data = ''.b
    @sizes = []
  end
  def write(chunk)
    @sizes << chunk.bytesize
    @data << chunk
    chunk.bytesize
  end
end

Dir.mktmpdir('mere-copy-cursor') do |dir|
  path = File.join(dir, 'source')
  content = ("a\x00\xff\n".b * 16385) + 'tail'
  File.binwrite(path, content)
  [[nil, nil], [16385, nil], [32769, 16383], [10, content.bytesize - 3],
   [12, content.bytesize], [0, 3]].each do |length, offset|
    sink = CursorCopySink.new
    copied = IO.copy_stream(Pathname.new(path), sink, length, offset)
    expected = content.byteslice(offset || 0, length || content.bytesize) || ''.b
    p [copied == expected.bytesize, sink.data == expected,
       sink.sizes.all? { |size| size > 0 && size <= 16384 }]
  end

  # Repeated calls start from the beginning; no cursor belongs to the path.
  3.times do
    dst = StringIO.new(''.b)
    p [IO.copy_stream(path, dst), dst.string == content]
  end
  target = File.join(dir, 'target')
  p [IO.copy_stream(path, target, 32770, 7), File.binread(target) == content.byteslice(7, 32770)]
  File.open(path, 'rb') do |src|
    src.pos = 9
    dst = StringIO.new(''.b)
    p [IO.copy_stream(src, dst, 20), src.pos, dst.string == content.byteslice(9, 20)]
  end
  begin
    sink = Object.new
    def sink.write(_chunk); raise IOError, 'destination failed'; end
    IO.copy_stream(path, sink)
  rescue IOError => e
    p e.message
  end
  dst = StringIO.new(''.b)
  p [IO.copy_stream(path, dst, 5), dst.string == content.byteslice(0, 5)]
end
