# Converters as test_econv asks (note 372). primitive_convert with a
# limited output reads one character more than fits and keeps it (nothing
# when what waits is already more than the room, and nothing ahead for a
# converter that converts nothing); ISO-2022-JP keeps its state from call to
# call, insert_output included, and the end closes it; a UTF-32 unit or a
# UTF-16 surrogate pair cut off by a partial input waits; a high surrogate
# followed by a non-low byte is broken there; negative offsets, a finished
# converter's #convert and a broken replacement string are refused.
def step(ec, src, dst, off, len, opts = nil, **kw)
  r = kw.empty? ? ec.primitive_convert(src, dst, off, len, opts) : ec.primitive_convert(src, dst, off, len, **kw)
  [dst.b, src.b, r]
end
ec = Encoding::Converter.new("UTF-8", "EUC-JP")
src = "abc\u{3042}def"; dst = ""
8.times { p step(ec, src, dst, nil, 1) }
ec = Encoding::Converter.new("", "")
src = "abcdefg"; dst = ""
4.times { p step(ec, src, dst, nil, 2) }
ec = Encoding::Converter.new("Shift_JIS", "EUC-JP")
src = "abc\xFFdef".b.force_encoding("Shift_JIS"); dst = ""
6.times { p step(ec, src, dst, nil, 1) }
ec = Encoding::Converter.new("EUC-JP", "ISO-2022-JP")
src = "".b; dst = ""
["a", "\xA2", "\xA4", "\xA1", "\xA2", "b", "\xA2\xA6"].each { |c| src << c.b; p step(ec, src, dst, nil, 50, partial_input: true) }
p step(ec, src, dst, nil, 50, 0)
ec = Encoding::Converter.new("EUC-JP", "ISO-2022-JP")
dst = ""
ec.primitive_convert("\xa1\xa1".b.force_encoding("EUC-JP"), dst, nil, 10, partial_input: true)
ec.insert_output("???")
ec.primitive_convert("", dst, nil, 10, partial_input: true)
ec.primitive_convert("\xa1\xa2".b.force_encoding("EUC-JP"), dst, nil, 10, partial_input: true)
ec.insert_output("\xA1\xA1".force_encoding("EUC-JP"))
ec.primitive_convert("", dst, nil, 10, partial_input: true)
p dst.b
ec = Encoding::Converter.new("UTF-32BE", "UTF-8")
src = "".b; dst = ""
["\x00", "\x00", "\x00", "A", "\x00", "\x00", "\xdc", "\x00", "\x00", "\x00", "\x00", "B"].each { |c| src << c.b; p step(ec, src, dst, nil, 50, partial_input: true) }
ec = Encoding::Converter.new("UTF-16BE", "UTF-8")
src = "".b; dst = ""
["\x00", "A", "\xd8", "\x00", "\x02", "\x01", "\xd8", "\x00", "\xdc", "\x00"].each { |c| src << c.b; p step(ec, src, dst, nil, 50, partial_input: true) }
ec = Encoding::Converter.new("UTF-16BE", "UTF-8")
src = "\xd8\x00\x00@".b
ec.primitive_convert(src, "", nil, 10)
p ec.primitive_errinfo.map { |x| x.is_a?(String) ? x.b : x }, src
ec = Encoding::Converter.new("UTF-8", "EUC-JP")
%w[dst_start dst_size].each_with_index do |w, i|
  begin
    i == 0 ? ec.primitive_convert("a", "b", -1, 1, partial_input: true) : ec.primitive_convert("a", "b", 1, -1, partial_input: true)
  rescue ArgumentError => e
    p [w, e.message]
  end
end
ec = Encoding::Converter.new("utf-8", "euc-jp")
p ec.primitive_convert(nil, "", nil, nil)
p((ec.convert("a") rescue $!.class))
p((Encoding::Converter.new("utf-8", "euc-jp").primitive_convert("a", "", nil, nil, {partial_input: true}) rescue $!.message))
p((Encoding::Converter.new("utf-8", "euc-jp", undef: :replace, replace: "\x80".force_encoding("euc-jp")) rescue $!.message))
p(("".encode("euc-jp", undef: :replace, replace: "\x80".force_encoding("euc-jp")) rescue $!.message))
