require 'zlib'
require 'stringio'

# Data is observed before FINISH, including across a full-flush boundary.
d = Zlib::Deflate.new
i = Zlib::Inflate.new
a = d.deflate("ab\0cd" * 30, Zlib::SYNC_FLUSH)
p i.inflate(a) == "ab\0cd" * 30
b = d.deflate('second', Zlib::FULL_FLUSH)
p i.inflate(b)
p i.inflate(d.deflate('last', Zlib::FINISH))
p [d.finished?, i.finished?, d.total_in, i.total_out]
d.close
i.close
begin
  d.finished?
rescue Zlib::Error
  p :closed
end

# A dictionary is requested, validated, and used without replaying the input.
d = Zlib::Deflate.new
d.set_dictionary('dictionary')
s = d.deflate('dictionary' * 20, Zlib::FINISH)
i = Zlib::Inflate.new
begin
  i.inflate(s)
rescue Zlib::NeedDict
  p :dictionary
end
i.set_dictionary('dictionary')
p i.inflate('') == 'dictionary' * 20
d.close
i.close

# Raw and gzip framing use the same stream engine.
[-15, 31].each do |window|
  d = Zlib::Deflate.new(6, window)
  s = d.deflate('binary\0data'.b, Zlib::FINISH)
  i = Zlib::Inflate.new(window)
  out = +''.b
  s.each_byte { |v| out << i.inflate(v.chr.b) }
  out << i.finish
  p [window, out == 'binary\0data'.b]
  d.close
  i.close
end

# Header metadata and finish keep the underlying IO available.
io = StringIO.new
w = Zlib::GzipWriter.new(io)
w.mtime = 0
w.orig_name = "file.txt\0ignored"
w.comment = 'comment'
w.write('first')
p w.finish.equal?(io)
p io.closed?
r = Zlib::GzipReader.new(StringIO.new(io.string))
p [r.mtime.to_i, r.orig_name, r.comment, r.read]
r.finish

p Zlib.adler32_combine(Zlib.adler32('first'), Zlib.adler32('last'), 4) == Zlib.adler32('firstlast')
p Zlib.crc32_combine(Zlib.crc32('first'), Zlib.crc32('last'), 4) == Zlib.crc32('firstlast')

# One-shot inflate discards bytes after its member; instances retain them.
encoded = Zlib.deflate('foo')
p Zlib.inflate(encoded + 'unused')
p Zlib::Inflate.inflate(encoded + 'unused')
[nil, true, 1].each do |value|
  [:deflate, :inflate].each do |method|
    begin; Zlib.send(method, value); rescue => e; p [method, e.class]; end
  end
end

# Sync before a header switches to raw; after a header it skips lost checks.
[false, true].each do |header_seen|
  d = Zlib::Deflate.new
  first = d.deflate('before', Zlib::FULL_FLUSH)
  last = d.deflate('after', Zlib::FINISH)
  i = Zlib::Inflate.new
  if header_seen
    i.inflate(first.byteslice(0, 2))
    bad = "\xff".b + first.byteslice(2, first.bytesize - 2) + last
  else
    bad = 'corrupt' + first + last
  end
  begin; i.inflate(bad); rescue Zlib::DataError; end
  p i.sync('')
  p i.inflate('') + i.finish
  i.close; d.close
end
