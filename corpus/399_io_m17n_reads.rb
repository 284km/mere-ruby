# Reading through a stateful encoding (getc, gets, ungetc), reading bytes that
# do not convert, UTF-16 characters from a pipe, a character split across two
# writes, the newline decorators on STDOUT, writing to STDIN, a character
# pushed back in text mode, and the warnings about the encodings a mode names
require "tmpdir"

warned = []
Warning.singleton_class.define_method(:warn) { |m, **| warned << m.sub(/\A.*?warning: /, "") }

Dir.mktmpdir do |dir|
  jis = File.join(dir, "jis")
  File.binwrite(jis, "before \e$B\x23\x30\x23\x31\e(B after\n".b)
  File.open(jis, "r:iso-2022-jp:euc-jp") do |f|
    cs = []
    while (c = f.getc)
      cs << c.encoding.to_s + ":" + c.bytes.map { |b| "%02x" % b }.join
    end
    p cs
  end
  File.open(jis, "r:iso-2022-jp:euc-jp") { |f| p f.gets("\xA3\xB0".force_encoding("euc-jp")).bytes.size }
  File.open(jis, "r:iso-2022-jp:euc-jp") do |f|
    c = f.getc
    f.ungetc(c)
    p f.read.bytesize
  end

  euc = File.join(dir, "euc")
  File.binwrite(euc, "\xA1\xA1x\xFFy\n".b)
  File.open(euc, "r:euc-jp") { |f| p f.gets.bytes, f.gets }
  File.open(euc, "r:euc-jp") { |f| p f.read.bytes }

  txt = File.join(dir, "txt")
  File.write(txt, "foo")
  File.open(txt, "r+t") do |f|
    f.ungetc(f.getc)
    %i[getbyte readpartial ungetbyte sysread].each do |m|
      r = begin
        m == :ungetbyte ? f.ungetbyte(0) : m == :getbyte ? f.getbyte : f.send(m, 2)
      rescue IOError => e
        e.message
      end
      p [m, r]
    end
    p f.read
  end
  File.open(txt, "r+") { |f| f.ungetc(f.getc); p f.read(2) }

  File.open(File::NULL, "rt:utf-8") { |f| f.ungetc("あい"); p f.each_codepoint.to_a }
  File.open(File::NULL, "rt:us-ascii") do |f|
    f.ungetc("あ")
    p((f.each_codepoint.to_a rescue [$!.class, $!.message]))
  end

  open(File::NULL, "r:bom|utf-" + "x" * 20) {}
  open(File::NULL, "r:bom|foo") {}
  open(File::NULL, "r:utf-8:bar") { |f| f.read; f.read }
  File.new(File::NULL, "r:baz").close
  open(File::NULL, encoding: "bom|qux") {}
end

r, w = IO.pipe("utf-16le:euc-jp", binmode: true)
w << "\x42\x30\x00\xd8\x46\x30".b
w.close
p r.getc.bytes
begin
  r.getc
rescue Encoding::InvalidByteSequenceError => e
  p e.error_bytes.bytes
end
p r.getc.bytes
r.close

r, w = IO.pipe("euc-jp:utf-8")
t = Thread.new { w.write "\xa1"; sleep 0.05; w.write "\xa1"; w.close }
p r.getc
t.join
r.close

begin
  IO.pipe("あ".encode("utf-16le")) {}
rescue ArgumentError => e
  p e.message
end

r, w = IO.pipe
w.puts "あ".encode("utf-32be")
w.close
p r.read.bytes
r.close

%w[cr crlf].each do |nl|
  out = IO.popen([RbConfig.ruby, "-e", "STDOUT.set_encoding('locale', newline: :#{nl}); puts 'a'; print \"b\\n\""], &:read)
  p out.bytes
end

p IO.popen([RbConfig.ruby, "-e", "begin; STDIN.write 'x'; rescue IOError => e; puts e.message; end"], "r+", &:read)

p warned
