# Generates the Grapheme_Cluster_Break property ranges embedded in main.mere
# (ENC_GCB_TABLE markers), by asking ruby's own regexp engine. One letter per
# class: C=Control R=CR L=LF P=Prepend E=Extend S=SpacingMark Z=ZWJ 1=L 2=V
# 3=T 4=LV 5=LVT I=Regional_Indicator X=Extended_Pictographic.
# Entries "lo-hi:K" hex, comma-separated, ascending.
props = {
  "C" => /\p{Grapheme_Cluster_Break=Control}/,
  "R" => /\p{Grapheme_Cluster_Break=CR}/,
  "L" => /\p{Grapheme_Cluster_Break=LF}/,
  "P" => /\p{Grapheme_Cluster_Break=Prepend}/,
  "E" => /\p{Grapheme_Cluster_Break=Extend}/,
  "S" => /\p{Grapheme_Cluster_Break=SpacingMark}/,
  "Z" => /\p{Grapheme_Cluster_Break=ZWJ}/,
  "1" => /\p{Grapheme_Cluster_Break=L}/,
  "2" => /\p{Grapheme_Cluster_Break=V}/,
  "3" => /\p{Grapheme_Cluster_Break=T}/,
  "4" => /\p{Grapheme_Cluster_Break=LV}/,
  "5" => /\p{Grapheme_Cluster_Break=LVT}/,
  "I" => /\p{Grapheme_Cluster_Break=Regional_Indicator}/,
  "X" => /\p{Extended_Pictographic}/,
}
klass = Array.new(0x110000)
props.each do |k, re|
  (0..0x10FFFF).each do |cp|
    next if (0xD800..0xDFFF).cover?(cp)
    ch = cp.chr(Encoding::UTF_8) rescue next
    # Extended_Pictographic does not override a real GCB class (Extend wins).
    next if k == "X" && klass[cp]
    klass[cp] = k if re.match?(ch)
  end
end
rows = []
lo = nil
(0..0x110000).each do |cp|
  k = cp <= 0x10FFFF ? klass[cp] : nil
  if lo && (k != klass[lo])
    rows << format("%X-%X:%s", lo, cp - 1, klass[lo])
    lo = nil
  end
  lo = cp if lo.nil? && k
end
puts rows.join(",")
