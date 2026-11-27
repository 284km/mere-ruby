# A pipe has no position: a File over one (here a pipe behind /dev/fd/N)
# refuses #seek, #pos, #tell, #pos=, #rewind and #sysseek with ESPIPE, as
# ruby's lseek does, and a refused seek loses nothing it would read next.
# Reading it by lines and by lengths, which move its position inside, still
# works; a regular file's position is as it was.
require 'tmpdir'
def t(name)
  r = begin; yield; rescue => e; "#{e.class}: #{e.message.sub(/ - .*/, '')}"; end
  puts "#{name}: #{r.inspect}"
end
def piped(text)
  r, w = IO.pipe
  w.write(text); w.close
  File.open("/dev/fd/#{r.fileno}") { |f| yield f }
ensure
  r&.close
end
t("seek 0")   { piped("abc") { |f| f.seek(0) } }
t("seek 1")   { piped("abc") { |f| f.seek(1) } }
t("seek end") { piped("abc") { |f| f.seek(-1, IO::SEEK_END) } }
t("seek cur") { piped("abc") { |f| f.seek(0, IO::SEEK_CUR) } }
t("seek sym") { piped("abc") { |f| f.seek(0, :SET) } }
t("pos")      { piped("abc") { |f| f.pos } }
t("tell")     { piped("abc") { |f| f.tell } }
t("pos=")     { piped("abc") { |f| f.pos = 1 } }
t("rewind")   { piped("abc") { |f| f.rewind } }
t("sysseek")  { piped("abc") { |f| f.sysseek(0) } }
t("read then seek")  { piped("abc") { |f| [f.read(1), (f.seek(0) rescue $!.class), f.read] } }
t("gets then pos")   { piped("a\nb\n") { |f| [f.gets, (f.pos rescue $!.class), f.gets, f.gets] } }
t("lines")           { piped("a\nb\nc") { |f| [f.gets, f.read(2), f.readlines] } }
t("each_line")       { piped("a\nb\n") { |f| f.each_line.to_a } }
t("getc and ungetc") { piped("xy") { |f| c = f.getc; f.ungetc(c); [f.read, f.eof?] } }
t("dup")             { piped("abc") { |f| f.read(1); f.dup.class } }
t("IO.pipe seek")    { r, w = IO.pipe; w.close; r.seek(0) }
t("IO.pipe pos")     { r, w = IO.pipe; w.close; r.pos }

Dir.mktmpdir do |d|
  p = File.join(d, "a.txt"); File.write(p, "line1\nline2\nline3\n")
  File.open(p) do |f|
    t("file gets pos") { [f.gets, f.pos, f.tell] }
    t("file seek")     { [f.seek(2), f.read(3), f.pos] }
    t("file seek end") { [f.seek(-6, IO::SEEK_END), f.gets] }
    t("file pos=")     { [f.pos = 6, f.gets] }
    t("file rewind")   { [f.rewind, f.gets, f.lineno] }
    t("file sysseek")  { f.rewind; f.sysseek(3) }
    t("file dup")      { f.seek(6); g = f.dup; [g.pos, g.gets] }
  end
  t("file reopen") { File.open(p) { |f| f.gets; g = File.open(p); g.reopen(f); [g.pos, g.gets] } }
  t("file bom")    { File.write(p, "\xEF\xBB\xBFab"); File.open(p, "r:BOM|UTF-8") { |f| [f.read, f.pos] } }
  t("file read len") { File.open(p) { |f| [f.read(2), f.pos, f.read(10), f.pos] } }
end
