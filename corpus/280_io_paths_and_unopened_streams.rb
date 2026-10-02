# IO.copy_stream takes anything with #to_path as a path before it asks it to
# read (a Pathname reads and writes whole files itself), and an IO that was
# only allocated inspects as any object and refuses #autoclose? with ruby's
# IOError -- what test_io and its leak checker ask of them.
require "pathname"
dir = "/tmp/mr280_#{$$}"
Dir.mkdir(dir)
src = File.join(dir, "src")
File.write(src, "copied by path")
p IO.copy_stream(Pathname.new(src), Pathname.new(File.join(dir, "dst"))), File.read(File.join(dir, "dst"))
o = Object.new
o.define_singleton_method(:to_path) { src }
p IO.copy_stream(o, File.join(dir, "dst2")), File.read(File.join(dir, "dst2"))
require "stringio"
p IO.copy_stream(StringIO.new("from a stream"), File.join(dir, "dst3")), File.read(File.join(dir, "dst3"))
Dir.children(dir).each { |f| File.delete(File.join(dir, f)) }
Dir.rmdir(dir)

io = IO.allocate
p io.inspect.match?(/\A#<IO:0x\h{16}>\z/)
p((io.autoclose? rescue $!.class), (io.autoclose? rescue $!.message))
r, w = IO.pipe
p r.autoclose?
r.close
p((r.autoclose? rescue $!.message), r.inspect)
w.close
