# EUC-KR, CP949 and GB18030 read and written through their tables (made from
# ruby's own transcoders), and three of the converter's judgments

u = "애인구함 朴지인"
kr = u.encode("euc-kr")
p kr.encoding, kr.bytes, kr.encode("UTF-8") == u
p "아햏".encode("cp949").encoding, "\x81\x41".dup.force_encoding("CP949").encode("UTF-8")
p (u.encode("EUC-KR").force_encoding("CP949").encode("UTF-8") == u)
begin; "갂".encode("EUC-KR"); rescue Encoding::UndefinedConversionError => e; p e.class; end

g = "啊\u0080\u{10000}\u{10FFFF}"
gb = g.encode("gb18030")
p gb.encoding, gb.bytes, gb.encode("UTF-8") == g
p "\x81\x30\x81\x30".dup.force_encoding("GB18030").encode("UTF-8").ord.to_s(16)
p "\x90\x30\x81\x30".dup.force_encoding("GB18030").encode("UTF-8").ord.to_s(16)
p (0x80..0xFFFF).step(97).reject { |c| (0xD800..0xDFFF).include?(c) }.all? { |c| s = [c].pack("U"); s.encode("GB18030").encode("UTF-8") == s }

p "\x8f\xa1!".dup.force_encoding("euc-jp").encode("utf-8", invalid: :replace)
%W[\x8e\xe0 \x8f\xa1\xa1 \x8e\xa1].each do |b|
  begin
    p b.dup.force_encoding("EUC-JP").encode("Shift_JIS").bytes
  rescue => e
    p e.class
  end
end
["\e(A", "\x0e", "\e(Babc"].each do |b|
  begin
    p b.dup.force_encoding("iso-2022-jp").encode("utf-8")
  rescue => e
    p e.class
  end
end
