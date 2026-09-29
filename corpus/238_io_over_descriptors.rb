# An IO made from a descriptor reads and writes THROUGH it, with ruby's
# buffers; a File's line readers take a separator, a limit, paragraph mode
# and chomp; pushback, BOMs and keyword options are the stream's own.
require "tmpdir"

dir = Dir.mktmpdir("mr300")
path = File.join(dir, "lines.txt")
File.write(path, "one\ntwo\n\n\nthree ü four\nfive")

# IO.sysopen + IO.new: a real descriptor, a write buffer, and a mode checked
# against what the descriptor was opened with
fd = IO.sysopen(path, "r")
io = IO.new(fd)
p io.gets, io.lineno, io.read(3), io.getc
p io.readlines(chomp: true)
p io.eof?
io.close
p io.closed?, io.inspect
begin
  IO.new(IO.sysopen(path, "r"), "w")
rescue Errno::EINVAL => e
  p e.class
end

# the line reader on a File
File.open(path) do |f|
  p f.gets("")          # a paragraph, and the newlines after it are swallowed
  p f.gets(nil, 5)      # a limit with no separator
  p f.gets(" ", chomp: true)
  p [f.lineno, $.]
  f.ungetc("X")
  p f.getc, f.pos
end
p IO.readlines(path, 4)
p File.foreach(path, "e").first(3)

# a pipe: both ends non-blocking as in ruby 3, the write end synchronous
r, w = IO.pipe
w.write("abc", 1)
w.puts [2, [3]]
w.close
p r.read, r.eof?
r.close

# keyword options reach File.open: the external encoding a write converts into
out = File.join(dir, "u16.txt")
File.open(out, "w", encoding: Encoding::UTF_16BE) { |f| p f.write("hi") }
p File.binread(out).bytes
File.binwrite(out, "\xEF\xBB\xBFbom")
p File.read(out, mode: "r:BOM|utf-8")

# IO.popen: the child's output through a pipe, and its status after close
IO.popen(["echo", "from", "child"]) { |c| p c.read }
p $?.exitstatus
p IO.popen("cat", "r+") { |c| c.write("round trip"); c.close_write; c.read }

File.delete(path, out)
Dir.rmdir(dir)
