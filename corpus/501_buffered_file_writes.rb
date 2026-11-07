# Small appends must survive collection, seeking, truncation, and independent
# handles. File#dup starts with its own flushed write buffer.
require 'tmpdir'

Dir.mktmpdir do |dir|
  path = File.join(dir, 'data')
  expected = ''
  File.open(path, 'w+b') do |f|
    1200.times do |i|
      piece = [i % 256, 0, 255].pack('C*')
      expected << piece
      f.write(piece)
      GC.start if i % 200 == 0
    end
    p f.pos
    f.flush
    p File.binread(path) == expected
    f.seek(10)
    f.write('xy')
    f.write('z')
    f.flush
    expected[10, 3] = 'xyz'
    p File.binread(path) == expected
    f.truncate(20)
    f.seek(0, IO::SEEK_END)
    f.write('tail')
    f.rewind
    p f.read == expected[0, 20] + 'tail'
  end

  File.open(path, 'ab') do |f|
    f.write('a')
    f.write('b')
    f.seek(0)
    f.write('c')
  end
  p File.binread(path).end_with?('tailabc')

  File.open(path, 'wb') do |f|
    f.write('first')
    other = f.dup
    other.seek(0, IO::SEEK_END)
    other.write('second')
    other.flush
    f.seek(0, IO::SEEK_END)
    f.write('third')
    f.flush
    other.close
  end
  p File.binread(path)

  File.open(path, 'wb') do |f|
    f.sync = true
    f.write('a')
    p File.binread(path)
    f.print('b', 'c')
    p File.binread(path)
  end
end
