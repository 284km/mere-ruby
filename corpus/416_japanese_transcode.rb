# Japanese encodings as ruby converts them (note 440).
def t(label)
  r = yield
  p [label, r]
rescue EncodingError => e
  p [label, e.class]
end

# ISO-2022-JP refuses what it has no escape for; CP50221 reads the
# half-width katakana in ESC ( I, after SO, and as high-bit bytes
t(:iso_esc_I) { "\x1b(I12345\x1b(B".encode("UTF-8", "ISO-2022-JP") }
t(:iso_so) { "\x0e".encode("UTF-8", "ISO-2022-JP") }
t(:iso_ok) { "\e$B!!\e(B".encode("UTF-8", "ISO-2022-JP") }
t(:cp50221_I) { "\e(I\x31\x32".encode("UTF-8", "CP50221") }
t(:cp50221_I8) { "\e(I\xB1".encode("UTF-8", "CP50221") }
t(:cp50221_so) { "\x0E\xB1\x0Fa".encode("UTF-8", "CP50221") }
t(:cp50221_8bit) { "a\xB1b".encode("UTF-8", "CP50221") }

# EUC-JIS-2004 (JIS X 0213), both ways
[["　", "\xA1\xA1"], ["×", "\xA1\xDF"], ["＇", "\xA2\xAF"],
 ["ゟ", "\xA2\xB9"], ["≢", "\xA2\xEB"]].each do |u, e|
  t(:ej2004) { [u.encode("EUC-JIS-2004").bytes, e.dup.force_encoding("EUC-JIS-2004").encode("UTF-8") == u] }
end
t(:ej2004_mixed) { "a＇b　c".encode("EUC-JIS-2004").bytes }
t(:ej2004_valid) { "\xA2\xAF".force_encoding("EUC-JIS-2004").valid_encoding? }

# UTF8-MAC decomposes, except the spans it keeps whole, and composes back
t(:mac_e) { "é".encode("UTF8-MAC").force_encoding("UTF-8").codepoints }
t(:mac_fb4d) { "\u{fb4d}".encode("UTF8-MAC").force_encoding("UTF-8").codepoints }
t(:mac_f900) { "\u{f900}".encode("UTF8-MAC").force_encoding("UTF-8").codepoints }
t(:mac_back) { "étè".encode("UTF-8", "UTF8-MAC").codepoints }
t(:mac_excl) { "כֿ".encode("UTF-8", "UTF8-MAC").codepoints }
