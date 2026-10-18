# Double-byte encodings and their kin, as test_transcode asks (note 360):
# GBK / GB2312 / Big5 (HKSCS, UAO) tables, an unmapped but well-formed pair
# is UndefinedConversionError, the JIS family's variants, EBCDIC, UTF-8's
# maximal subparts and lone surrogates.
def t(l) = (puts "#{l}: #{(begin; yield; rescue Exception => e; "#{e.class}: #{e.message}"; end).inspect}")
[["\xA1\x40","Big5"],["\xA1\x7E","Big5"],["\xAF\xFE","Big5"],["\xC6\x7E","Big5"],["\xA0\x80","GBK"],["\xA1\xA1","GBK"],["\xA2\xB1","GBK"],["\xA1\xA1","GB2312"],["\x81\x40","Big5-UAO"],["\x87\x40","Big5-HKSCS"],["\xA1\x40","Big5-HKSCS"],["\x80","GBK"]].each do |b, e|
  t("dec #{e} #{b.unpack1('H*')}") { s = b.dup.force_encoding(e).encode("UTF-8"); [s, s.encode(e).b == b.b] }
end
[["\xA3\xC0","Big5","UTF-8"],["\xA3\xC0","Big5","EUC-JP"],["\xF0\x40","Shift_JIS","UTF-8"],["\xA9\xA1","EUC-JP","UTF-8"],["\xA2\xA0","GBK","UTF-8"],["\xA2\xA0","GBK","UTF-16LE"],["\xA1","Big5","UTF-8"],["\x81\x30","Big5","UTF-8"],["\x81","GBK","UTF-8"],["\xFF","GBK","UTF-8"]].each do |s, f, to|
  t("err #{f} #{s.unpack1('H*')} #{to}") { s.dup.force_encoding(f).encode(to) }
end
t("rep") { "\xA3\xC0x".force_encoding("Big5").encode("UTF-8", undef: :replace) }
t("enc_undef") { "".encode("Big5") }
t("enc_ok") { ["　﹚".encode("Big5").b, "　".encode("GB2312").b, "丂".encode("GBK").b, "€".encode("GBK").b] }
t("valid") { ["\xA1\x40".force_encoding("Big5").valid_encoding?, "\xA1\x30".force_encoding("Big5").valid_encoding?, "\xA1\x40".force_encoding("Big5").size] }
t("eucjp") { "\xA4\xDE\xA4\xC4".force_encoding("EUC-JP").encode("UTF-8") }
t("sjis_ok") { "\x82\xA0".force_encoding("Shift_JIS").encode("UTF-8") }
t("w31j") { ["\x81\xCA", "\x87\x40", "\xED\x40", "\xFA\x40"].map { |b| (b.dup.force_encoding("Windows-31J").encode("UTF-8") rescue $!.class) } }
t("w31j_rev") { ["￢", "①", "纊", "ⅰ", "¬"].map { |c| (c.encode("Windows-31J").b rescue $!.class) } }
t("eucms") { ["\xAD\xE2", "\xA1\xC1", "\x7E", "\x5C"].map { |b| (b.dup.force_encoding("eucJP-ms").encode("UTF-8") rescue $!.class) } }
t("cp51932") { ["\xAD\xE2", "\x7E", "\x5C", "\xA4\xA2"].map { |b| (b.dup.force_encoding("CP51932").encode("UTF-8") rescue $!.class) } }
t("ebcdic") { "\x81\x82\xC1".force_encoding("IBM037").encode("UTF-8") }
t("ebcdic_rev") { "abA".encode("IBM037").b }
t("u16bom") { [%w/feffdfb7/.pack("H*"), %w/fffeb7df/.pack("H*")].map { |s| (s.force_encoding("UTF-16").encode("UTF-8") rescue $!.class) } }
t("u32bom") { [%w/0000feff0000dfb7/.pack("H*"), %w/fffe0000b7df0000/.pack("H*")].map { |s| (s.force_encoding("UTF-32").encode("UTF-8") rescue $!.class) } }
t("ill") { ["\xE0\x80", "\xF0\x80\x80", "\xC0\xAF", "\xED\xA0\x80"].map { |s| s.dup.force_encoding("UTF-8").encode("UTF-16BE", invalid: :replace).encode("UTF-8").size } }
t("2022_tilde") { ["~".encode("ISO-2022-JP"), "\\".encode("ISO-2022-JP")] }
