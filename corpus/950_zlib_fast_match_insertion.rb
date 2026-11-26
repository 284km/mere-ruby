require "zlib"
require "stringio"

source = "Hello World" * 100
fast = Zlib::Deflate.deflate(source, Zlib::BEST_SPEED)
best = Zlib::Deflate.deflate(source, Zlib::BEST_COMPRESSION)
p best.bytesize < fast.bytesize

# The fast levels share a match finder but use different insertion thresholds.
# Exercise matches on both sides of those thresholds, binary data and history.
data = ("abcXabcYabcdXabcdYabcdeXabcdeYabcdefXabcdefY" * 15).b
samples = ["", source, data, (0..255).to_a.pack("C*") * 3]
[0, 1, 2, 3, 4, 6, 9, Zlib::DEFAULT_COMPRESSION].each do |level|
  p [level, samples.all? { |s| Zlib.inflate(Zlib.deflate(s, level)) == s }]
end
[Zlib::DEFAULT_STRATEGY, Zlib::FILTERED, Zlib::HUFFMAN_ONLY, Zlib::RLE, Zlib::FIXED].each do |strategy|
  p [strategy, [1, 2, 3].all? { |level|
    d = Zlib::Deflate.new(level, Zlib::MAX_WBITS, Zlib::DEF_MEM_LEVEL, strategy)
    encoded = d.deflate(data, Zlib::FINISH)
    d.close
    Zlib.inflate(encoded) == data
  }]
end
[1, 2, 3].each do |level|
  d = Zlib::Deflate.new(level)
  encoded = d.deflate(data, Zlib::SYNC_FLUSH)
  encoded << d.deflate(source, Zlib::FULL_FLUSH)
  encoded << d.deflate(data, Zlib::FINISH)
  d.close
  p [level, Zlib.inflate(encoded) == data + source + data]
  io = StringIO.new
  w = Zlib::GzipWriter.new(io, level)
  w.write(data)
  w.write(source)
  w.finish
  p Zlib::GzipReader.new(StringIO.new(io.string)).read == data + source
end
