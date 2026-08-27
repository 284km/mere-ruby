# Generates the EUC-JP (JIS X 0208) <-> Unicode table embedded in main.mere
# between the ENC_JIS0208_TABLE markers. One entry per code: 4 hex digits of
# the EUC byte pair, then the codepoint in hex, comma-separated. Halfwidth
# katakana (SS2) and JIS X 0212 (SS3) are arithmetic / out of scope here.
#
#   ruby tools/gen_jis0208.rb > /tmp/jis0208.txt   # then splice (see header)
rows = []
(0xA1..0xFE).each do |l|
  (0xA1..0xFE).each do |t|
    begin
      u = [l, t].pack("C2").force_encoding("EUC-JP").encode("UTF-8")
      rows << format("%02X%02X:%X", l, t, u.ord)
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    end
  end
end
puts rows.join(",")
