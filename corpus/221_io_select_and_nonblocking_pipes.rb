# IO.select, IO#wait / wait_readable / wait_writable and the non-blocking
# read and write pair were all missing: a pipe could be read and written but
# never ASKED whether it was ready, and Kernel#select was a NoMethodError.
# They are poll(2) now, and a pipe answers what ruby's does -- including the
# EAGAIN a full or empty one raises, and the bytes #getc read ahead.
r, w = IO.pipe
p IO.select([r], nil, nil, 0)
p IO.select([r], [w], nil, 0).map { |a| a.map { |io| io.equal?(r) ? :r : :w } }
p r.wait(IO::READABLE, 0), w.wait(IO::WRITABLE, 0), [IO::READABLE, IO::PRIORITY, IO::WRITABLE]
p r.read_nonblock(5, exception: false)
begin
  r.read_nonblock(5)
rescue IO::WaitReadable => e
  p [e.class, e.is_a?(Errno::EAGAIN), e.message]
end
w.write "hello world"
p select([r], [], [], 0).first.size
s = r.read_nonblock(4)
p [s, s.encoding]
buf = "old".encode(Encoding::ISO_8859_1)
p r.read_nonblock(3, buf), buf.encoding
p r.getc, r.ungetc("X"), r.read_nonblock(100)
p r.wait_readable(0), r.wait(0, :r)
n = 0
loop do
  x = w.write_nonblock("a" * 4096, exception: false)
  break if x == :wait_writable
  n += x
end
p n > 0, w.wait(IO::WRITABLE, 0), w.wait_writable(0)
begin
  w.write_nonblock("a")
rescue IO::WaitWritable => e
  p e.class
end
p r.read(n).size
w.close
p IO.select([r], nil, nil, 0).first.size, r.read_nonblock(1, exception: false)
[[Object.new], 1].each do |bad|
  begin
    IO.select(*[bad].flatten(0))
  rescue TypeError => e
    p e.message
  end
end
[-1, Float::NAN, "x"].each do |t|
  begin
    IO.select(nil, nil, nil, t)
  rescue => e
    p [e.class, e.message]
  end
end
begin
  STDOUT.wait(0, :sideways)
rescue ArgumentError => e
  p e.message
end
p STDOUT.wait_writable(0).equal?(STDOUT)
