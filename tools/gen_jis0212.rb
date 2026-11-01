# Generates the EUC-JP JIS X 0212 (SS3: 0x8F + two bytes) <-> Unicode table
# embedded in m_codec.mere between the ENC_JIS0212_TABLE markers, as
# tools/gen_jis0208.rb does for JIS X 0208: "LLTT:CP" -- the two bytes after
# 0x8F in hex, then the codepoint in hex -- comma-separated.
#
#   ruby tools/gen_jis0212.rb > /tmp/jis0212.txt   # then splice
rows = []
(0xA1..0xFE).each do |l|
  (0xA1..0xFE).each do |t|
    begin
      u = [0x8F, l, t].pack("C3").force_encoding("EUC-JP").encode("UTF-8")
      next unless u.size == 1
      # (every code that reads: the one character JIS X 0208 has as well is
      #  written back there, because the encoder asks JIS X 0208 first)
      rows << format("%02X%02X:%X", l, t, u.ord)
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    end
  end
end
puts rows.join(",")
