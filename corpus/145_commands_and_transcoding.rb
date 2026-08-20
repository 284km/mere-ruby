# Two answers that used to be wrong QUIETLY, which is worse than missing.
#
# 1. A command literal returned "". The comment above it said mere cannot spawn
#    a subprocess -- but Mere has had `run` since v0.1.13, and the same file uses
#    it for File.directory?. The output is captured through a file, because `run`
#    answers with the exit status; stdout only, as ruby's backticks are.
p `echo hi`.strip
p `printf 'a\nb\n'`.lines.length
p `exit 3`.length
p [system("true"), system("false")]

# 2. `encode` answered with the SAME BYTES for every target it did not know,
#    because anything that was not UTF-8 fell into a one-byte-per-codepoint
#    branch: "ab".encode("UTF-16BE").bytesize was 2 where ruby says 4. UTF-16 is
#    written properly now, in both byte orders, with surrogate pairs.
p "ab".encode("UTF-16BE").bytes
p "ab".encode("UTF-16LE").bytes
p "あ".encode("UTF-16BE").bytes
p "\u{1F600}".encode("UTF-16BE").bytes
p "あiu".encode("UTF-16BE").encode("UTF-8").bytes
p "あiu".encode("UTF-16LE").encode("UTF-8") == "あiu"

# ... and the targets that need no conversion still answer, with the name given
p "ab".encode("US-ASCII").bytesize
p "é".encode("ISO-8859-1").bytes
p "ab".encode("Shift_JIS").bytesize
p "あ".encode("utf-8").bytesize
p "ab".encode("ASCII-8BIT").encoding.to_s

# a codepoint the target cannot hold is refused, as it is in ruby
begin
  "あ".encode("US-ASCII")
rescue Encoding::UndefinedConversionError => e
  p e.class
end
