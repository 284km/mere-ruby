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

# with a length, a path without an end is read only that far, and the bytes
# are BINARY; an offset is a seek, which a character device takes and a pipe
# refuses (even 0)
p File.read("/dev/urandom", 16).bytesize
p File.binread("/dev/zero", 4)
p File.read("/dev/zero", 3, 5)
p IO.read("/dev/urandom", 8).bytesize
p File.read("/dev/zero", 0)
p File.read(__FILE__, 2).encoding, File.read(__FILE__, 2, 1).encoding, File.read(__FILE__).encoding
t("pipe offset")  { piped("abcdefgh") { |p| File.read(p, 3, 2) } }
t("pipe offset 0") { piped("abc") { |p| File.binread(p, 2, 0) } }

# a negative length or offset is refused before anything is read: /dev/zero
# never ends. IO.read refuses a negative offset first; IO.binread seeks to it,
# which a character device takes and a pipe refuses, and then refuses a
# negative length.
%i[read binread].each do |m|
  [File, IO].each do |k|
    t("#{k}.#{m} zero -1")    { k.send(m, "/dev/zero", -1) }
    t("#{k}.#{m} zero -1 0")  { k.send(m, "/dev/zero", -1, 0) }
    t("#{k}.#{m} zero 2 -1")  { k.send(m, "/dev/zero", 2, -1) }
    t("#{k}.#{m} zero -1 -1") { k.send(m, "/dev/zero", -1, -1) }
    t("#{k}.#{m} pipe -1")    { piped("abc") { |p| k.send(m, p, -1) } }
    t("#{k}.#{m} pipe -1 0")  { piped("abc") { |p| k.send(m, p, -1, 0) } }
    t("#{k}.#{m} pipe 1 -1")  { piped("abc") { |p| k.send(m, p, 1, -1) } }
    t("#{k}.#{m} file -1")    { k.send(m, __FILE__, -1) }
    t("#{k}.#{m} file 1 -1")  { k.send(m, __FILE__, 1, -1) }
  end
end

# a length or an offset that is not an Integer is converted as ruby converts
# it (a Float truncates, #to_int is asked, a String is refused), before
# anything is read: /dev/urandom never ends
neg = Object.new; def neg.to_int = -1
two = Object.new; def two.to_int = 2
bad = Object.new; def bad.to_int = "x"
%i[read binread].each do |m|
  [File, IO].each do |k|
    t("#{k}.#{m} -1.0")       { k.send(m, "/dev/urandom", -1.0) }
    t("#{k}.#{m} 2.7")        { k.send(m, "/dev/zero", 2.7) }
    t("#{k}.#{m} to_int -1")  { k.send(m, "/dev/urandom", neg) }
    t("#{k}.#{m} to_int 2")   { k.send(m, "/dev/zero", two) }
    t("#{k}.#{m} to_int bad") { k.send(m, "/dev/zero", bad) }
    t("#{k}.#{m} string")     { k.send(m, "/dev/urandom", "bad") }
    t("#{k}.#{m} nil")        { k.send(m, __FILE__, nil).size > 0 }
    t("#{k}.#{m} nil 1")      { k.send(m, __FILE__, nil, 1)[0, 3] }
    t("#{k}.#{m} 2 1.5")      { k.send(m, "/dev/zero", 2, 1.5) }
    t("#{k}.#{m} 2 string")   { k.send(m, "/dev/zero", 2, "x") }
    t("#{k}.#{m} 2 to_int")   { k.send(m, "/dev/zero", 2, two) }
    t("#{k}.#{m} bignum")     { k.send(m, "/dev/zero", 2**70) }
    t("#{k}.#{m} string -1")  { k.send(m, "/dev/zero", "x", -1) }
  end
end

# ...and a Float that has no long -- NaN, the infinities, one past a long --
# is a RangeError before anything is read, as a length and as an offset (an
# offset is binread's off_t, "long long" where an off_t is not a long)
[Float::INFINITY, -Float::INFINITY, Float::NAN, 1e100, -1e100, 9.3e18, 2.0**63].each do |x|
  %i[read binread].each do |m|
    [File, IO].each do |k|
      t("#{k}.#{m} #{x}")         { k.send(m, "/dev/zero", x) }
      t("#{k}.#{m} 1 #{x}")       { k.send(m, "/dev/zero", 1, x) }
      t("#{k}.#{m} file 1 #{x}")  { k.send(m, __FILE__, 1, x) }
    end
  end
  t("File#read #{x}")         { File.open("/dev/zero") { |f| f.read(x) } }
  t("File#readpartial #{x}")  { File.open("/dev/zero") { |f| f.readpartial(x) } }
  t("File#sysread #{x}")      { File.open("/dev/zero") { |f| f.sysread(x) } }
  t("File#read_nonblock #{x}") { File.open("/dev/zero") { |f| f.read_nonblock(x) } }
  t("pipe read #{x}")         { piped("ab\n") { |p| File.open(p) { |f| f.read(x) } } }
  t("File#gets #{x}")         { File.open(__FILE__) { |f| f.gets(x) } }
  t("File#seek #{x}")         { File.open(__FILE__) { |f| f.seek(x) } }
  t("File#sysseek #{x}")      { File.open(__FILE__) { |f| f.sysseek(x) } }
end

# a File read over a pipe and then reopened onto a file reads the file
Dir.mktmpdir do |d|
  f = File.join(d, "fresh.txt"); File.write(f, "fresh\n")
  t("pipe reopened") { piped("old\n") { |p| File.open(p) { |io| [io.read, io.reopen(f).class, io.read] } } }
  t("pipe reopened, gets") { piped("old\n") { |p| File.open(p) { |io| [io.gets, (io.reopen(f, "r"); io.gets), io.gets] } } }
end

# a read with a length reads only the length, from the offset: a length of 0
# is "" at any offset (past the end too), and a big offset is a seek, not
# 1 TiB read and dropped
def sz(v) = v.nil? ? nil : [v.bytesize, v.encoding.to_s]
size = File.size(__FILE__)
[[File, :read], [File, :binread], [IO, :binread], [IO, :read]].each do |k, m|
  [0, 16, 2**40].each do |off|
    t("#{k}.#{m} urandom 0 #{off}") { sz(k.send(m, "/dev/urandom", 0, off)) }
    t("#{k}.#{m} zero 3 #{off}")    { k.send(m, "/dev/zero", 3, off) }
  end
  [3, size, size + 100].each do |off|
    t("#{k}.#{m} file 0 at #{off - size}") { sz(k.send(m, __FILE__, 0, off)) }
    t("#{k}.#{m} file 2 at #{off - size}") { sz(k.send(m, __FILE__, 2, off)) }
  end
  t("#{k}.#{m} file 2 at -1") { k.send(m, __FILE__, 2, size - 1) }
end
t("File#pread urandom 0 2**40") { File.open("/dev/urandom") { |f| f.pread(0, 2**40) } }
t("File#pread zero 2 2**40")    { File.open("/dev/zero") { |f| f.pread(2, 2**40) } }

# a file that cannot be read is EACCES, with a length of 0 too: binread opens
# before anything, read after its offset's refusals and before its length's
Dir.mktmpdir do |d|
  f = File.join(d, "u.txt"); File.write(f, "secret"); File.chmod(0, f)
  [[File, :read], [File, :binread], [IO, :read], [IO, :binread]].each do |k, m|
    [[], [0], [1], [1, 2], [-1], [1, -1], ["x"], [1, "x"], [Float::INFINITY]].each do |a|
      t("#{k}.#{m} unreadable #{a.inspect}") { k.send(m, f, *a) }
    end
  end
  t("readlines unreadable") { File.readlines(f) }
  t("foreach unreadable") { File.foreach(f).to_a }
  File.chmod(0o600, f)
end
