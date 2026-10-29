# Encodings after sweep464: an ISO-2022-JP source decoded with its shift
# state (partial input, an invalid byte), an Encoding that cannot be copied,
# "%p" taking no encoding from its argument, and EUC-JP <-> Shift_JIS by
# JIS arithmetic for the rows Unicode has no character for.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

def step(ec, src, dst)
  r = ec.primitive_convert(src, dst, nil, 50, partial_input: true)
  [dst.b, src.b, r]
end

ec = Encoding::Converter.new("ISO-2022-JP", "EUC-JP")
src = +""
dst = +""
steps = []
["a", "\e", "$", "B", "\x21", "\x22", "\n", "\x23", "\x24", "\e", "(", "B", "c", "\n"].each do |b|
  src << b
  steps << step(ec, src, dst)
end
steps.each_with_index { |s, i| puts "jis #{i}: #{s.inspect}" }

show("bad byte") do
  ec2 = Encoding::Converter.new("ISO-2022-JP", "EUC-JP")
  d = +""
  r = ec2.primitive_convert(+"abc\xFF", d, nil, 100)
  [r, d.b, ec2.primitive_errinfo[0..2]]
end

show("Encoding#dup") { Encoding::UTF_8.dup }
show("Encoding#clone") { Encoding::UTF_8.clone }
show("Marshal keeps it") { Marshal.load(Marshal.dump(Encoding::UTF_8)).equal?(Encoding::UTF_8) }

bin = "\xC2\xA1".b
show("%p encoding") { ("%10p".encode("US-ASCII") % bin).encoding }
show("%s encoding") { ("%s".encode("US-ASCII") % bin.inspect).encoding }

{ "\xfd\xa1" => "\xef\x40", "\xfd\xe0" => "\xef\x80", "\xfe\xfe" => "\xef\xfc", "\xa4\xa2" => "\x82\xa0" }.each do |e, s|
  show("euc #{e.unpack1('H*')}") { [e.dup.force_encoding("EUC-JP").encode("Shift_JIS").b == s.b, s.dup.force_encoding("Shift_JIS").encode("EUC-JP").b == e.b] }
end
show("kana past DF") { "\x8e\xe0".force_encoding("EUC-JP").encode("Shift_JIS") }
show("%p UTF-8 arg") { ("%p" % "é").encoding }
show("%p ASCII format, UTF8-MAC arg") { ("%p".encode("US-ASCII") % "é".force_encoding("UTF8-MAC")).encoding }
show("UTF-16 format") { sprintf("%p".encode("UTF-16LE"), nil) }
