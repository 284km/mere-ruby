# Empty reads and pushback do not need disk bytes. Keep their encodings,
# positions, stream checks, and subsequent real reads intact; seek still
# flushes buffered writes and SEEK_END still asks for the current size.
require 'tmpdir'

Dir.mktmpdir do |dir|
  path = File.join(dir, 'data')
  File.binwrite(path, "abc\ndef\n")
  File.open(path, 'r:utf-8') do |f|
    empty = f.read(0)
    p [empty, empty.encoding, f.pos]
    p f.read(2)
    f.ungetbyte('XY')
    p [f.read(0), f.read(1), f.read(2), f.pos]
    p [f.seek(-1, IO::SEEK_CUR), f.pos, f.read(2)]
    p [f.seek(-2, IO::SEEK_END), f.pos, f.read]
    p [f.read(0), f.read(1), f.read]
    f.seek(20)
    buf = 'replace'.encode('UTF-16LE')
    p [f.read(0, buf).equal?(buf), buf.bytes, buf.encoding, f.pos, f.read(1)]
    f.rewind
    p [f.pos, f.gets, f.pos, f.gets, f.pos, f.gets]
  end

  File.open(path, 'r+b') do |f|
    f.write('XY')
    f.read(0)
    f.seek(0)
    p [f.read(2), File.binread(path)]
    f.seek(0, IO::SEEK_END)
    f.write('tail')
    p [f.seek(-4, IO::SEEK_END), f.pos, f.read]
    f.seek(1)
    p [f.seek(1, IO::SEEK_CUR), f.pos, f.read(1)]
  end
  File.open(path, 'wb') do |f|
    begin
      f.read(0)
    rescue IOError => e
      p e.class
    end
  end
  f = File.open(path, 'rb')
  f.close
  begin
    f.read(0)
  rescue IOError => e
    p e.class
  end
  File.open(path, 'rb') { |io| p [io.read(0), io.read(1), io.read] }
  File.open('/dev/zero', 'rb') { |io| p [io.read(0), io.read(3).bytes] }

  # Cross the line reader's 8192-byte refill boundary and rewind its read-ahead.
  data = "short\r\n" + 'x' * 9000 + "\r\nlast"
  File.binwrite(path, data)
  p File.foreach(path, mode: 'rb').map { |s| [s.bytesize, s[-4, 4]] }
  File.open(path, 'rt', universal_newline: true) do |io|
    p [io.read(0), io.gets, io.pos]
    io.rewind
    p io.each_line.map { |s| s.bytesize }
  end
end
