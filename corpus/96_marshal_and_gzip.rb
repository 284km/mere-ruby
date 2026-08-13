# Marshal.load over the subset a data file uses, and the gzip stream classes
# on top of the vendored zlib. Everything here is built in-process: the
# compressed bytes come from Zlib.gzip, so the program reads only what it wrote.
require "zlib"

# --- Marshal.load ---------------------------------------------------------
def dump_of(hex)
  hex.scan(/../).map { |h| h.to_i(16).chr }.join
end
# these are CRuby's own Marshal.dump output for the values named beside them
p Marshal.load(dump_of("040830"))                          # nil
p Marshal.load(dump_of("040854"))                          # true
p Marshal.load(dump_of("040846"))                          # false
p Marshal.load(dump_of("0408690a"))                        # 5
p Marshal.load(dump_of("040869022c01"))                    # 300
p Marshal.load(dump_of("040869fed4fe"))                    # -300
p Marshal.load(dump_of("04083a0873796d"))                  # :sym
p Marshal.load(dump_of("0408220973747200"))                # "str\0", binary
p Marshal.load(dump_of("0408220973747200")).encoding
p Marshal.load(dump_of("04085b0869066906690a"))            # [1, 1, 5]
p Marshal.load(dump_of("04087b063a06616906"))              # {:a => 1}
p Marshal.load(dump_of("04086608312e35"))                  # 1.5
p Marshal.load(dump_of("04085b073a06613b00"))              # [:a, :a] via symlink
p Marshal.load(dump_of("0408492208616263063a064546"))      # "abc" with its encoding
p Marshal.load(dump_of("0408492208616263063a064546")).encoding
begin
  Marshal.load("nope")
rescue TypeError => e
  p :type_error
end

# --- gzip -----------------------------------------------------------------
payload = (["hello world"] * 40).join("\n")
gz = Zlib.gzip(payload)
p gz.bytesize > 0
p Zlib.gunzip(gz) == payload
p gz.bytes.first(3)                                      # 1f 8b 08

path = "/tmp/mere_ruby_corpus_96.gz"
File.open(path, "wb") { |f| f.write(gz) }
File.open(path, "rb") do |io|
  p Zlib::GzipReader.new(io).read == payload
end
p Zlib::GzipReader.open(path) { |r| r.read.bytesize }
r = Zlib::GzipReader.open(path)
p r.read(5)
p r.pos
p r.gets
p r.eof?
r.rewind
p r.readlines.size
File.delete(path)

# a round trip through GzipWriter, read back by GzipReader
File.open(path, "wb") { |f| Zlib::GzipWriter.new(f).tap { |w| w.write(payload) }.close }
p Zlib::GzipReader.open(path) { |g| g.read } == payload
File.delete(path)

# a marshal dump inside a gzip member, which is how a gem ships an index
data = Zlib.gzip(dump_of("04085b0769066905690a"))
p Marshal.load(Zlib.gunzip(data))
