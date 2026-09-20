# The names StringIO was missing. Each expected value was measured against the
# reference ruby, and three of them are not what the name suggests:
#
#   #putc returns its ARGUMENT, not the byte it wrote.
#   #lineno counts calls to #gets, so readline/readlines/each_line advance it
#     and #getc does not -- and #rewind puts it back to 0.
#   #ungetbyte PREPENDS at position 0 and OVERWRITES anywhere else.
#
# ...and #write was appending. ruby writes AT the position, which is why
# `StringIO.new("ab").write("q")` is "qb" and not "abq".

require "stringio"
def io(str = "ab\ncd\n", mode = "r+") = StringIO.new(str.dup, mode)

p io.binmode.class
p [io.getbyte, io.readbyte, io.readchar, io.readline]
p StringIO.new("ab").each_byte.to_a
p StringIO.new("ab").each_char.to_a
p StringIO.new("ab").each_codepoint.to_a
p((a = []; StringIO.new("ab").each_byte { |b| a << b }; a))
x = io; p [x.lineno, x.gets && x.lineno, x.readline && x.lineno, x.rewind && x.lineno]
x = io; x.lineno = 7; p [x.lineno, x.gets]
p((x = io("", "w"); x.putc("hi"); x.putc(65); [x.string, x.putc(66)]))
p((x = io; x.getbyte; x.ungetbyte(122); x.read))
p((x = io; x.ungetbyte(122); [x.pos, x.string]))
p((x = io; x.read(2); x.ungetbyte("XY"); [x.pos, x.string]))
p [io.pid, io.fsync, io.sysread(2), io.read_nonblock(2)]
p((x = io("", "w"); [x.write_nonblock("hi"), x.string]))
p((x = io; x.reopen("zz"); [x.read, x.string]))

# the two halves close independently, and each refuses by NAME
p((x = io; x.close_read; [x.closed_read?, x.closed?, (begin; x.read; rescue IOError => e; e.message; end)]))
p((x = io; x.close_write; [x.closed_write?, (begin; x.write("q"); rescue IOError => e; e.message; end)]))
p((x = io; x.close_read; x.close_write; x.closed?))
p((begin; StringIO.new("ab", "r").write("q"); rescue IOError => e; e.message; end))
p((begin; StringIO.new("", "w").read; rescue IOError => e; e.message; end))
p((begin; StringIO.new("").readbyte; rescue EOFError => e; e.message; end))
p((begin; io.fcntl(1, 2); rescue NotImplementedError; "NotImplementedError"; end))

# ruby writes AT the position, and pads a gap past the end with NUL
p((x = StringIO.new("ab"); x.write("q"); x.string))
p((x = StringIO.new("abcd", "r+"); x.read(2); x.write("Z"); [x.pos, x.string]))
p((x = StringIO.new("ab", "r+"); x.seek(4); x.write("Z"); x.string.bytes))

# "a" leaves the position at 0 and sends every write to the end, even after a seek
p((x = StringIO.new("abcd", "a"); x.seek(1); x.write("Z"); [x.pos, x.string]))
p StringIO.new("ab", "a").pos

# a nil separator means "the rest"
p StringIO.new("a\nb").gets(nil)
p StringIO.new("a\nb").readlines(nil)
