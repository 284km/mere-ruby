# Generates the Unicode case-mapping tables embedded in m_codec.mere using
# the reference Ruby. Entries are "CP:CP[ CP...]" hex, comma-separated.
# FOLD, TITLE and SWAP store exceptions to downcase, upcase and the usual
# lower/upper swap respectively, including identity mappings when necessary.
# only ASCII is excluded: the arithmetic core answers Latin-1/Greek/Cyrillic
# too, but claiming a range here silently drops its irregular members (the
# first version dropped 0xDF, and eszett stopped upcasing).
def covered_arith(cp)
  cp < 0x80
end
def table(kind)
  rows = []
  (0x80..0x2FFFF).each do |cp|
    next if (0xD800..0xDFFF).cover?(cp)
    ch = cp.chr(Encoding::UTF_8) rescue next
    out = case kind
          when :up then ch.upcase
          when :down then ch.downcase
          when :fold then ch.downcase(:fold)
          when :title then ch.capitalize
          when :swap then ch.swapcase
          end
    fallback = case kind
               when :fold then ch.downcase
               when :title then ch.upcase
               when :swap then ch.downcase == ch ? ch.upcase : ch.downcase
               else ch
               end
    next if out == fallback
    next if covered_arith(cp)
    rows << format("%X:%s", cp, out.codepoints.map { |c| format("%X", c) }.join(" "))
  end
  rows.join(",")
end
puts "UP"; puts table(:up)
puts "DOWN"; puts table(:down)
puts "FOLD"; puts table(:fold)
puts "TITLE"; puts table(:title)
puts "SWAP"; puts table(:swap)
