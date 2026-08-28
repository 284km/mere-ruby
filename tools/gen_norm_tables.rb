# Generates the Unicode normalization tables embedded in main.mere
# (ENC_NORM_TABLES markers), asking ruby's own String#unicode_normalize.
# Hangul syllables (AC00-D7A3) are algorithmic and excluded. Sections:
#   NFD   "CP:CP[ CP..]"  canonical decompositions, fully expanded
#   NFKD  "CP:CP[ CP..]"  compatibility decompositions differing from NFD
#   CCC   "CP:RANK"       nonzero combining-class ORDER (ranks, not the UCD
#                         values: normalization only compares classes, and the
#                         ranks are derived from ruby's own reordering)
#   COMP  "CP CP:CP"      canonical composition pairs (exclusions already
#                         absent, because each pair is checked against nfc)
HANGUL = (0xAC00..0xD7A3)
nfd_rows, nfkd_rows, comp_rows = [], [], []
(0x80..0x2FFFF).each do |cp|
  next if (0xD800..0xDFFF).cover?(cp) || HANGUL.cover?(cp)
  ch = [cp].pack("U")
  nfd = ch.unicode_normalize(:nfd)
  nfkd = ch.unicode_normalize(:nfkd)
  if nfd != ch
    nfd_rows << format("%X:%s", cp, nfd.codepoints.map { |c| format("%X", c) }.join(" "))
    # the composition PAIR is the first-level decomposition: recompose all but
    # the last mark ("s + dot-below + dot-above" pairs as (1E63, 0307)).
    if nfd.codepoints.size >= 2
      a = nfd.codepoints[0..-2].pack("U*").unicode_normalize(:nfc)
      if a.codepoints.size == 1
        pair = [a.ord, nfd.codepoints[-1]]
        if pair.pack("U*").unicode_normalize(:nfc) == ch
          comp_rows << format("%X %X:%X", *pair, cp)
        end
      end
    end
  end
  nfkd_rows << format("%X:%s", cp, nfkd.codepoints.map { |c| format("%X", c) }.join(" ")) if nfkd != nfd
end
# nonzero-combining-class codepoints: they reorder past U+0345 (ccc 240, the
# highest), plus U+0345 itself; their relative ORDER is ruby's reordering.
marks = [0x0345]
(0x80..0x2FFFF).each do |cp|
  next if (0xD800..0xDFFF).cover?(cp) || HANGUL.cover?(cp) || cp == 0x0345
  ch = [cp].pack("U")
  probe = "אͅ#{ch}"
  marks << cp if probe.unicode_normalize(:nfd).codepoints[1] == cp
end
sorted = marks.sort do |a, b|
  s = "א#{[b].pack("U")}#{[a].pack("U")}".unicode_normalize(:nfd).codepoints
  if s[1] == a && s[2] == b then -1
  else
    t = "א#{[a].pack("U")}#{[b].pack("U")}".unicode_normalize(:nfd).codepoints
    (t[1] == b && t[2] == a) ? 1 : 0
  end
end
ccc_rows = []
rank = 0
prev = nil
sorted.each do |cp|
  if prev
    s = "א#{[cp].pack("U")}#{[prev].pack("U")}".unicode_normalize(:nfd).codepoints
    rank += 1 if s[1] == prev && s[2] == cp   # strictly greater than prev
  else
    rank = 1
  end
  ccc_rows << format("%X:%d", cp, rank)
  prev = cp
end
puts "NFD";  puts nfd_rows.join(",")
puts "NFKD"; puts nfkd_rows.join(",")
puts "CCC";  puts ccc_rows.join(",")
puts "COMP"; puts comp_rows.join(",")
