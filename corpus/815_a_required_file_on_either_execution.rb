# A required file runs the same whichever execution takes it: one the ISeq VM
# compiles, and one it declines -- a source in another encoding, a BEGIN, a
# shareable_constant_value write -- which runs on the evaluator as parsed.
# What a file leaves behind outlives its load: a proc, a method and where it
# was written, a constant table, a block that closes over the file's locals.
# A file that does not parse is a SyntaxError naming it, and is not loaded.
require "tmpdir"
dir = Dir.mktmpdir("c815")
w = ->(name, src, enc = nil) { File.binwrite(File.join(dir, name), enc ? src.encode(enc) : src); File.join(dir, name) }

w.("plain.rb", <<~RUBY)
  TABLE815 = (0...3000).map { |i| i * 7 % 13 }.freeze
  x = 40
  KEEP815 = proc { |y| x += y }
  def plain815(a, b = 2) = [a, b, __method__]
  module Plain815; def self.where = [__FILE__ == $plain815, __LINE__]; end
  $loaded815 = ($loaded815 || []) << :plain
  require_relative "nested"
RUBY
w.("nested.rb", "$loaded815 << :nested\nNESTED815 = __dir__ == File.dirname(__FILE__)\n")
w.("sjis.rb", "# coding: Windows-31J\nSJIS815 = \"あい\"\ndef sjis815 = [SJIS815.encoding, SJIS815.bytesize, __ENCODING__]\n$loaded815 << :sjis\n", "Windows-31J")
w.("begin.rb", "$loaded815 << :body\nBEGIN { ($loaded815 ||= []) << :begin }\nBEGIN815 = 1\n")
w.("shareable.rb", "# shareable_constant_value: literal\nSHARE815 = [1, [2, 3], {a: \"s\"}]\n$loaded815 << :shareable\n")
w.("bad.rb", "def broken815(\n  1 +\nend end\n")
w.("warns.rb", "h815 = {a: 1, a: 2}\n$loaded815 << h815\n")

$plain815 = File.join(dir, "plain.rb")
p require($plain815), require($plain815)
p TABLE815.size, TABLE815.sum, TABLE815.frozen?, NESTED815
p KEEP815.call(2), KEEP815.call(3), plain815(1), Plain815.where
p method(:plain815).source_location[1], method(:plain815).arity, KEEP815.source_location[1]
require File.join(dir, "sjis")
p sjis815, SJIS815 == "あい".encode("Windows-31J")
require File.join(dir, "begin")
require File.join(dir, "shareable")
p BEGIN815, SHARE815, SHARE815.frozen?, SHARE815[1].frozen?, Ractor.shareable?(SHARE815)
begin
  require File.join(dir, "bad")
rescue SyntaxError => e
  p e.class, e.path == File.join(dir, "bad.rb"), e.message.lines.size > 1
end
p defined?(broken815), $LOADED_FEATURES.any? { _1.end_with?("bad.rb") }
err = $stderr; rd, wr = IO.pipe; $stderr = wr
require File.join(dir, "warns")
$stderr = err; wr.close
p rd.read.lines.map { _1.sub(dir, "D").sub(/\A.*?warns/, "warns") }
p $loaded815
Dir.glob(File.join(dir, "*")).each { File.delete(_1) }; Dir.rmdir(dir)
