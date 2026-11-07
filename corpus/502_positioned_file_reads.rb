require 'tmpdir'

Dir.mktmpdir do |dir|
  path = File.join(dir, 'data')
  data = (0..255).to_a.pack('C*') * 600
  File.binwrite(path, data)
  [1, 65535, 65536, 65537, 200000].each do |length|
    File.open(path, 'rb') do |f|
      f.seek(7)
      actual = f.read(length)
      expected = data.byteslice(7, length)
      p [length, actual == expected, actual.encoding, f.pos]
    end
  end
  File.open(path, 'rb') do |f|
    f.seek(data.bytesize - 3)
    f.ungetbyte('xyz')
    p [f.read(0), f.read(2), f.read(10).bytes, f.pos, f.read(1)]
    f.seek(data.bytesize + 5)
    p [f.read(1), f.pos, f.read(0)]
  end
  File.open(path, 'r+b') do |f|
    p f.read(2).bytes
    f.write('XY')
    f.seek(1)
    p f.read(4).bytes
    f.truncate(3)
    f.seek(2)
    p [f.read(20), f.pos, f.read(1)]
  end
  File.open(path, 'rb') do |f|
    p f.read(1).bytes
    File.binwrite(path, 'updated')
    p f.read(3)
    File.truncate(path, 0)
    p [f.read(1), f.read(0)]
  end
  File.binwrite(path, "first\r\nsecond\rlast\n")
  File.open(path, 'rt', universal_newline: true) do |f|
    p [f.read(3), f.gets, f.read]
  end
  File.open('/dev/zero', 'rb') { |f| p f.read(3).bytes }
  File.open(File::NULL, 'rb') { |f| p [f.read(1), f.read(0), f.read] }
end
