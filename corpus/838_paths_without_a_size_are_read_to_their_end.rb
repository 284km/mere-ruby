# A path that gives its bytes without a size is read to its end, as ruby
# reads it: a pipe behind /dev/fd/N (as /dev/stdin is), read whole by
# File.read and its kin, and line by line through a File over it -- the
# line reader's read-ahead is not lost. (/proc/self/status, a regular file
# of size 0, is the same on Linux.) A regular file that is empty when opened
# still sees what is written to it later.
require 'tmpdir'
def t(name)
  r = begin; yield; rescue => e; "#{e.class}: #{e.message.sub(/ - .*/, '')}"; end
  puts "#{name}: #{r.inspect}"
end
def piped(text)
  r, w = IO.pipe
  w.write(text); w.close
  yield "/dev/fd/#{r.fileno}"
ensure
  r&.close
end
t("pipe read")      { piped("ab\ncd\n") { |p| File.read(p) } }
t("pipe binread")   { piped("ab\ncd\n") { |p| File.binread(p).encoding } }
t("pipe IO.read")   { piped("ab\ncd\n") { |p| IO.read(p) } }
t("pipe len")       { piped("abcdef") { |p| File.read(p, 3) } }
t("pipe readlines") { piped("ab\ncd\n") { |p| File.readlines(p) } }
t("pipe foreach")   { piped("ab\ncd\n") { |p| File.foreach(p).to_a } }
t("pipe open read") { piped("ab\ncd\n") { |p| File.open(p, &:read) } }
t("pipe gets")      { piped("ab\ncd\n") { |p| File.open(p) { |f| [f.gets, f.gets, f.gets] } } }
t("pipe empty")     { piped("") { |p| File.read(p) } }
Dir.mktmpdir do |d|
  f = File.join(d, "a.txt"); File.write(f, "xyz")
  e = File.join(d, "e.txt"); File.write(e, "")
  t("file")      { File.read(f) }
  t("file len")  { File.read(f, 2, 1) }
  t("empty")     { File.read(e) }
  t("empty len") { File.read(e, 1) }
  t("dir")       { File.read(d) }
  t("missing")   { File.read(File.join(d, "nope")) }
end

require 'tempfile'
t = Tempfile.new('x'); t.write("abc"); t.rewind; p t.read; t.close!
Dir.mktmpdir do |d|
  f = File.join(d, 'g.log'); File.write(f, "")
  r = File.open(f, 'r')
  p r.read, r.eof?
  File.write(f, "line1\n", mode: 'a')
  p r.gets, r.eof?
  File.write(f, "line2\n", mode: 'a')
  p r.read
  r.close
  w = File.open(File.join(d, 'w.txt'), 'w+'); w.write("hello\nworld\n"); w.rewind; p w.readlines; w.close
  e = File.join(d, 'e.txt'); File.write(e, "")
  p File.read(e), File.readlines(e), File.open(e, &:eof?)
  big = File.join(d, 'b.txt'); File.write(big, (1..5).map { |i| "l#{i}\n" }.join)
  File.open(big) { |io| p [io.gets, io.read(3), io.gets, io.eof?, io.read, io.eof?]; io.seek(-3, IO::SEEK_END); p io.read }
end
