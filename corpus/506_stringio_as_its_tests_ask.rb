# StringIO, as test/stringio asks (note 511's stage 3): the null device
# (StringIO.new(nil)), a mode's spelling, "BOM|UTF-8", #pread, a limit
# beside a non-String separator, paragraphs of CRLF lines and their chomp,
# the separator in a UTF-16 buffer's encoding, a buffer given to #read with
# no length taking the stream's encoding, a frozen buffer's IOError, a
# write past the largest position, read_nonblock's required length, and a
# US-ASCII buffer taking the encoding of the first non-ASCII string written.
require "stringio"
io = StringIO.new(nil)
p io.gets, io.puts("abc"), io.string, io.ungetc("#"), io.getc, io.read, io.write("x")
p((io.pread(1, 0) rescue $!.class))
%w[x rx rbt r+b rb+ wt a+].each { |m| print m, " ", (StringIO.new(+"", m) rescue $!.class).class, "\n" }
p((StringIO.new(Object) rescue $!.class), (StringIO.new("".freeze, "w") rescue $!.class))
text = "﻿Āa"
%w[UTF-8 UTF-16BE UTF-16LE UTF-32BE UTF-32LE].each do |name|
  content = text.encode(name)
  r = StringIO.new(content, mode: "rb:BOM|UTF-8").read
  p [name, r.encoding, r.b == content[1..].b, StringIO.open(content) { |f| f.set_encoding_by_bom }]
end
f = StringIO.new("pread"); f.read
p f.pread(3, 0), f.pread(4, 1), f.pread(4, 1).encoding
b = "".b; f.pread(3, 0, b); p b
p((f.pread(1, 5) rescue $!.class), (f.pread(-1, 0) rescue $!.class), (f.pread(3, -1) rescue $!.class))
p((StringIO.new("").gets(1, 1) rescue $!.class), StringIO.new("").gets(nil, nil), StringIO.new("foo").gets(0))
p StringIO.new("abc\r\n\r\ndef\r\n").gets(chomp: true), StringIO.new("abc\r\n\r\ndef\r\n").gets("", chomp: true)
s = StringIO.new("abc\r\n\r\ndef\r\n"); p s.gets("", chomp: true), s.gets("", chomp: true)
s = StringIO.new("abc\n\ndef\n"); p s.gets("", chomp: true), s.gets("", chomp: true)
p StringIO.new("foo\nbar\n\n\nbaz\n").each("").to_a, StringIO.new("foo\nbar\n\n\nbaz\n").each("", chomp: true).to_a
p StringIO.new("foo\r\nbar\r\n\r\n\r\nbaz\r\n").each("").to_a, StringIO.new("foo\r\nbar\r\n\r\n\r\nbaz\r\n").each("", chomp: true).to_a
p StringIO.new("abc\n\ndef\n").each(nil, 2, chomp: true).to_a, StringIO.new("\n\n\na\n\nb").each("").to_a
u = StringIO.new("line1\nline2\n".encode("utf-16le")); p u.gets == "line1\n".encode("utf-16le"), u.gets == "line2\n".encode("utf-16le"), u.gets
f = StringIO.new("あい"); s = +"0123456789"; p f.read(nil, s).equal?(s), s, s.encoding
p f.read.encoding, f.read(nil, nil).encoding; s.force_encoding("US-ASCII"); f.read(nil, s); p s.encoding
f.rewind; s = +""; f.read(4, s); p s.encoding
f = StringIO.new("".freeze); p((f.write("foo") rescue $!.class), (f.ungetc("a") rescue $!.class), (f.ungetbyte("a") rescue $!.class))
s = +""; f = StringIO.new(s, "w"); s.freeze; p((f.write("foo") rescue $!.class), (StringIO.allocate.read rescue $!.class))
f = StringIO.new; f.pos = StringIO::MAX_LENGTH; p((f.write("x") rescue $!.class))
f = StringIO.new("あい")
p((f.read_nonblock(-1, exception: false) rescue $!.class), (f.read_nonblock rescue $!.class), f.read_nonblock(100, exception: false), f.read_nonblock(10, exception: false))
s = StringIO.new.set_encoding(Encoding::US_ASCII); s.write("foo".force_encoding("US-ASCII"), "あ"); p s.string.encoding, s.string
s = StringIO.new.set_encoding(Encoding::Windows_31J); s.write("あ"); p s.string.encoding, s.string.bytes
s = StringIO.new.set_encoding(Encoding::UTF_8); s.write("foo".force_encoding("ISO-8859-1"), "あ"); p s.string.encoding
