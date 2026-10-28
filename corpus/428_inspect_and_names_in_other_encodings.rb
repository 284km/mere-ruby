# Strings, Symbols and class names in an encoding other than UTF-8: what
# #inspect writes and in which encoding, a constant's name, the messages
# that name it, and patterns built from strings that disagree.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect.b.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message.b.inspect}"
end

$VERBOSE = nil

# a Shift_JIS name whose second byte is `]` is one letter
Encoding.default_external = Encoding::Windows_31J
sjis = "{\x87]: 1}".force_encoding("sjis")
show("sjis key") { eval(sjis).inspect == sjis }

# inspect writes in the default encoding, and its String is in it
[Encoding::UTF_8, Encoding::EUC_JP, Encoding::Windows_31J].each do |e|
  Encoding.default_external = e
  s = "\xa1\xa2".force_encoding("EUC-JP").inspect
  show("euc in #{e}") { [s, s.encoding] }
  t = "abc".inspect
  show("ascii in #{e}") { t.encoding }
end
Encoding.default_external = Encoding::UTF_8

# a constant named in ISO-8859-1 keeps the name in it, and Marshal can
# write and read it
klass = Class.new
Object.const_set("R\xe9sum\xe9".force_encoding(Encoding::ISO8859_1), klass)
show("latin1 name") { [klass.name, klass.name.encoding] }
show("marshal") { Marshal.load(Marshal.dump(klass)).equal?(klass) }

# a class named in EUC-JP, and a UTF-8 message that names it
alias $標準出力 $stdout
x = eval("class X\u{307b 3052}; self; end".encode("euc-jp"))
show("euc name") { [x.name.encoding, x.name.valid_encoding?] }
show("message") do
  begin
    $標準出力 = x.new
  rescue TypeError => e
    [e.message.encoding, e.message.valid_encoding?, e.message.end_with?("X\u{307b 3052} given")]
  ensure
    $stdout = STDOUT
  end
end

# two interpolated strings that disagree, and a literal piece that does
u = "あ"
j = "\x82\xa0".force_encoding("Windows-31J")
show("interpolated") { /#{u}#{j}/ }
show("plain strings") { "#{u}#{j}" }
show("agree") { /#{u}#{"b"}/.source }
