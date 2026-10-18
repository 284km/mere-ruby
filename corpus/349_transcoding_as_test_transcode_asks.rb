# Transcoding as test_transcode asks (note 373): EUC-JIS-2004 reads and writes
# as EUC-JP; CESU-8 is UTF-8 with a character past the BMP as its two
# surrogates; UTF8-MAC text comes out composed; ISO-2022-JP and CP5022x are
# decoded state by state (ESC ( B / ESC ( J / ESC $ B / ESC $ @ / ESC ( I), so a
# same-encoding xml: escape no longer touches the JIS X 0208 bytes; ISO-2022-JP
# and stateless-ISO-2022-JP convert byte for byte; and a magic comment that
# names no encoding, or one there is not, is refused.
p "　".encode("euc-jis-2004").b, "\xA1\xA1".force_encoding("euc-jis-2004").encode("UTF-8")
p "まつもと".encode("euc-jis-2004").encode("UTF-8", "euc-jis-2004")
p "\u{10000}".encode("CESU-8").bytes, "\xED\xA0\x80\xED\xB0\x80".force_encoding("CESU-8").encode("UTF-8")
p "\xC3\xBC \xDF\xBF".force_encoding("CESU-8").encode("UTF-8")
p "כֿ".encode("UTF-8", "UTF8-MAC"), "ῷ".encode("UTF-8", "UTF8-MAC"), "é".encode("UTF-8", "UTF8-MAC")
p "\e(B\x5C\e(B".encode("UTF-8", "ISO-2022-JP"), "\e(J\x5C\e(B".encode("UTF-8", "ISO-2022-JP")
p "\e$B\x21\x21\e(B".encode("UTF-8", "ISO-2022-JP"), "\e(B\x21".encode("utf-8", "cp50221"), "\e(J\x21".encode("utf-8", "cp50221")
p "<>湿".encode("ISO-2022-JP").encode("ISO-2022-JP", xml: :text).encode("UTF-8")
p "<>湿".encode("ISO-2022-JP").encode("ISO-2022-JP", xml: :attr).encode("UTF-8")
s = "\e$B~~\e(B".force_encoding("iso-2022-jp")
s2 = s.encode(Encoding::Converter.asciicompat_encoding("ISO-2022-JP"))
p s2.b, s2.encode("ISO-2022-JP") == s
p "a\e$B!!\e(Bb".force_encoding("iso-2022-jp").encode("stateless-ISO-2022-JP").b
require 'tmpdir'
Dir.mktmpdir do |d|
  ["# coding: bogus-enc", "# Encoding::Converter x", "# -*- coding: utf-8 -*-", "# encoding=latin1", "# coding: binary"].each do |l|
    File.write(File.join(d, "m.rb"), "#{l}\np __ENCODING__\n")
    out = IO.popen([RbConfig.ruby, File.join(d, "m.rb"), err: [:child, :out]], &:read)
    p [l, out.lines.first.to_s.gsub(d, "D").sub(/\(ArgumentError\).*/m, "(ArgumentError)").strip]
  end
  File.write(File.join(d, "lib.rb"), "# coding: bogus\n1\n")
  p((begin; require File.join(d, "lib"); rescue ArgumentError => e; e.message.sub(File.realpath(d), "D").sub(d, "D").lines.first.strip; end))
end
p((begin; eval("# coding: bogus\n1"); rescue ArgumentError => e; e.message.lines.first.strip; end))
