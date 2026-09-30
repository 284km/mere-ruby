# String#lines / #each_line follow CRuby's rb_str_enumerate_lines: the block
# form of #lines yields and answers the receiver, paragraph mode keeps exactly
# two newlines, chomp: removes only the separator it was given, and a
# separator that is not a String is refused.
a = []
s = "one\ntwo\r\nthree"
p(s.lines { |x| a << x }.equal?(s), a)
p "hello\nworld\n\n\nand\nuniverse\n\n\n\n\ndog".lines("")
p "hello\r\nworld\n\n\nand\nuniverse\n\n\n\r\n\r\ndog".each_line("").to_a
p "hello\nworld\n\n\nand\nuniverse\n\n\n\n\n".lines("", chomp: true)
p "\n\n\nx".lines(""), "a\nb\n".lines("", chomp: true)
p "hello \r\nworld\r\n".each_line(chomp: true).to_a
p "hello\r\n world\r\n".lines(" ", chomp: true)
p "".lines(nil), "".lines(false), "x".lines(nil)
[false, :o, 1].each do |sep|
  begin
    "hello world".each_line(sep) {}
  rescue TypeError => e
    p e.message
  end
end
p "hello world".each_line(" ").size
p "a\nb".encode("UTF-16LE").lines.map { |l| l.encode("UTF-8") }
p "a\nb".encode("UTF-16").lines.size
begin
  "a\nb".dup.force_encoding("UTF-7").lines
rescue Encoding::ConverterNotFoundError => e
  p e.class
end
begin
  "a\nb".encode("UTF-16LE").lines("\n")
rescue Encoding::CompatibilityError => e
  p e.message
end
old = $/
$VERBOSE = nil
$/ = "l"
p "hello world".lines
$/ = old

# String#<< and #concat are one operation: a String argument negotiates the
# result's encoding, an Integer is a codepoint in the receiver's encoding, an
# object is asked for #to_str, and anything else is a TypeError -- whichever
# way the method is reached.
o = Object.new
def o.to_str = "world!"
p(+"hello " << o, (+"hello ").send(:<<, o), (+"hello ").concat(o))
p((+"").concat(33, 0x203D))
a = "".encode("US-ASCII") << 200
p a, a.encoding
[-> { "".encode("US-ASCII") << 256 }, -> { "".encode("EUC-JP") << 0x81 },
 -> { +"" << -200 }, -> { (+"").concat(2**70) }, -> { +"x" << [] },
 -> { (+"x").concat(Object.new) }, -> { "x".encode("UTF-16LE") << "y" },
 -> { +"é" << "é".encode("ISO-8859-1") }].each do |f|
  begin
    p f.call
  rescue RangeError, TypeError, Encoding::CompatibilityError => e
    p [e.class, e.message]
  end
end
p "".encode("UTF-16LE").concat("x").encoding, (+"").concat("x".encode("UTF-16LE")).encoding
p (+"abc").concat("é".encode("ISO-8859-1")).encoding
s = +"hello"
s.concat(s, s)
p s
t = +"x"
t.method(:<<).call("q")
p t

# Encoding.compatible? is rb_enc_compatible: an empty ASCII-compatible first
# String keeps its encoding against an ASCII-only second, and a Symbol, a
# Regexp or an Encoding is only an encoding, never text.
e = ["", "abc", "\xE9"]
%w[UTF-8 US-ASCII ASCII-8BIT ISO-8859-1 UTF-16LE].each do |ea|
  %w[UTF-8 US-ASCII ASCII-8BIT ISO-8859-1 UTF-16LE].each do |eb|
    row = e.product(e).map do |sa, sb|
      x = sa.dup.force_encoding(ea)
      y = sb.dup.force_encoding(eb)
      c = Encoding.compatible?(x, y)
      r = begin; (x.dup << y).encoding; rescue Encoding::CompatibilityError; nil; end
      "#{c.inspect}/#{r.inspect}"
    end
    puts "#{ea} #{eb} #{row.join(' ')}"
  end
end
p Encoding.compatible?("あ", Encoding::US_ASCII)
p Encoding.compatible?("\xa4\xa2".dup.force_encoding("euc-jp").to_sym, :abc)
p Encoding.compatible?(Regexp.new("\xa4\xa2".dup.force_encoding("euc-jp")), "hello")
p Encoding.compatible?("".encode("US-ASCII"), "")

# String#encode: a fallback's answer must be a String the destination can
# hold, xml: escapes and quotes, the no-destination form follows
# Encoding.default_internal, an encoding may be named through #to_str, and an
# encoding with no converter is refused rather than guessed.
def t
  p yield
rescue ArgumentError, TypeError, EncodingError => e
  p [e.class, e.message]
end
t { "B�".encode("US-ASCII", fallback: { "�" => "bar" }) }
t { h = {}; h.default = "dflt"; "B�".encode("US-ASCII", fallback: h) }
t { "B�".encode("US-ASCII", fallback: ->(c) { c.bytes.inspect }) }
t { "B�".encode("US-ASCII", fallback: ->(c) { "￮" }) }
t { "B�".encode("US-ASCII", fallback: ->(c) { Object.new }) }
t { "B�".encode("US-ASCII", fallback: Object.new) }
t { '& < > " x'.encode("UTF-8", xml: :text) }
t { '& < > " x'.encode("UTF-8", xml: :attr) }
t { "ürst".encode("US-ASCII", xml: :attr) }
t { "a\xFF<".encode(xml: :text) }
t { "".encode("UTF-8", xml: :other) }
t { "abc".encode("xyz") }
t { "\x80".b.encode("Emacs-Mule") }
t { "\x79".b.encode("Emacs-Mule") }
t { "aあいbうc".encode("ISO-2022-JP").b }
t { "a\xFFb".encode("UTF-8", undef: :replace) }
t { "a\xFFb\xA4".force_encoding("EUC-JP").encode("EUC-JP", invalid: :replace) }
t { "\x81a\xA0\xFF".force_encoding("Shift_JIS").scrub.b }
begin
  Encoding.default_internal = "UTF-8"
  t { "\xA4\xA2".force_encoding("EUC-JP").encode }
ensure
  Encoding.default_internal = nil
end
enc = Object.new
def enc.to_str = "utf-8"
t { "\xA4\xA2".force_encoding("EUC-JP").encode(enc) }
