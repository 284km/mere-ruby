# Streams whose writes share one converter, and paths that keep the
# encoding they were written in, as test_io_m17n asks
require "tmpdir"

def pipe_out(enc, *chunks, sync: true)
  r, w = IO.pipe
  w.sync = sync
  w.set_encoding(enc)
  chunks.each { |c| w << c }
  w.close
  s = r.read.b
  r.close
  s
end

# a stateful external encoding: one converter for the whole stream
p pipe_out("iso-2022-jp", "あ", "い")
p pipe_out("iso-2022-jp", "あ", "\x82\xa2".dup.force_encoding("sjis"))
p pipe_out("iso-2022-jp", "あ", "a", "い")
p pipe_out("iso-2022-jp", "a", "あ")
p pipe_out("iso-2022-jp", "あ", "い", sync: false)
p pipe_out("iso-2022-jp:utf-8", "あ", "い")
p pipe_out("iso-2022-jp", "あ\n", "い\n")
p pipe_out("cp50221", "あ", "ｱ")
r, w = IO.pipe
w.set_encoding("iso-2022-jp"); w.print("あ", "い"); w.puts("う"); w.write("え", "x"); w.close
p r.read.b
r.close

Dir.mktmpdir do |dir|
  Dir.chdir(dir) do
    # xml: :text / :attr escape every write; :attr quotes the whole stream
    open("raw.txt", "wb", xml: :attr) { |f| f.print '&<>"\''; f.puts "丂あ" }
    p File.binread("raw.txt")
    open("ascii.txt", "wb:us-ascii", xml: :attr) { |f| f.print '&<>"\''; f.puts "丂あ" }
    p File.binread("ascii.txt")
    open("iso.txt", "wb:iso-2022-jp", xml: :attr) { |f| f.print '&<>"\''; f.puts "丂あ" }
    p File.binread("iso.txt")
    open("u16.txt", "wb:utf-16be", xml: :attr) { |f| f.print '&<>"\''; f.puts "丂あ" }
    p File.binread("u16.txt")
    open("text.txt", "wb", xml: :text) { |f| f.print %q(&<>"'); f.print "あ" }
    p File.binread("text.txt")
    open("empty.txt", "wb", xml: :attr) { |f| }
    p File.binread("empty.txt")

    # a path keeps the encoding (and bytes) it was written in
    pa = "\u{3042}".encode("sjis")
    File.open(pa, "w") { |f| p [f.path.encoding, f.path == pa, f.inspect.encoding] }
    begin
      File.open("nx" + pa)
    rescue SystemCallError => e
      p [e.class, e.message.encoding, e.message.b.end_with?(("nx" + pa).b)]
    end
    s = "a/あ.rb".encode("sjis")
    p [File.basename(s).encoding, File.dirname(s).encoding, File.extname(s).encoding, File.split(s).map(&:encoding)]
    p File.basename(s, ".rb").bytes
  end
end

# a File closed twice answers nil both times
f = File.open(__FILE__)
p [f.close, f.close, f.closed?]
