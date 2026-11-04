# The version describes the generated Unicode 17 tables; its String is ASCII
# and frozen independently of RbConfig's mutable configuration.
require 'rbconfig'
v = Encoding::UNICODE_VERSION
p [v, v.encoding, v.frozen?, v == RbConfig::CONFIG['UNICODE_VERSION']]
p([0x1C89, 0xA7CE, 0x10D50, 0x16EA0].map { |cp| [cp].pack('U').downcase.codepoints })
p([0x1C8A, 0xA7CF, 0x10D70, 0x16EBB].map { |cp| [cp].pack('U').upcase.codepoints })
p([0x105C9, 0x11383, 0x16121].map { |cp| [cp].pack('U').unicode_normalize(:nfd).codepoints })
p ["\u{16EA0}".match?(/\p{Beria_Erfe}/), "\u{11DB0}".match?(/\p{Tolong_Siki}/)]
