# Generates the Unicode case-mapping tables embedded in main.mere between the
# ENC_CASE_TABLES markers, asking ruby's own String#upcase/#downcase (and
# downcase(:fold) for casecmp?'s folding). Only mappings the arithmetic core
# (ASCII, Latin-1, Greek, Cyrillic offsets) does NOT already cover are listed.
# Entries are "CP:CP[ CP...]" hex, comma-separated; three tables: UP, DOWN, FOLD.
def covered_arith(cp)
  return true if cp < 0x80                    # ASCII
  return true if (0xC0..0xFF).cover?(cp)      # Latin-1
  return true if (0x391..0x3C9).cover?(cp)    # Greek core
  return true if (0x400..0x45F).cover?(cp)    # Cyrillic core
  false
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
          end
    next if out == ch
    next if kind != :fold && covered_arith(cp)
    # fold table only needs entries that differ from plain downcase
    next if kind == :fold && out == ch.downcase && covered_arith(cp)
    next if kind == :fold && out == ch.downcase && !covered_arith(cp)
    rows << format("%X:%s", cp, out.codepoints.map { |c| format("%X", c) }.join(" "))
  end
  rows.join(",")
end
puts "UP"; puts table(:up)
puts "DOWN"; puts table(:down)
puts "FOLD"; puts table(:fold)
