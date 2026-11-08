# Generates the Unicode case-mapping tables embedded in m_codec.mere using
# the reference Ruby. Entries are "CP:CP[ CP...]" hex, comma-separated.
# PAGES is an ASCII 0/1 mask of the pages containing any table entry.
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
tables = %i[up down fold title swap].to_h { |kind| [kind, table(kind)] }
tables.each { |kind, rows| puts kind.to_s.upcase; puts rows }
# Most Unicode codepoints have no case mapping. One byte per 256-codepoint
# page lets the walker avoid hexadecimal key construction and table lookups
# there. A marked page may contain unchanged characters; an unmarked one
# must not contain any entry, including an identity exception.
pages = tables.values.flat_map { |rows| rows.split(',').map { |r| r.to_i(16) / 256 } }.uniq
puts "PAGES"
puts (0..pages.max).map { |page| pages.include?(page) ? '1' : '0' }.join
