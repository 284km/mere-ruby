# Generates the Unicode property tables embedded in m_unicode.mere (between
# the ENC_UPROP_TABLES markers): what `[[:alpha:]]`, `\p{L}`, `\p{Han}` and
# their spellings mean on a non-ASCII character. ruby's own regexp engine is
# the oracle -- every set below is read back from it, never from a data file.
#
#   uprop_raw  "lo-hi:V" (hex): V = general category index + 32 * POSIX bits.
#              A codepoint in no range is Cn (index 0) with no bits.
#   usc_raw    "lo-hi:K" (hex): K = script index (0 = Unknown, not listed).
#   uname_raw  "name:X", one per property NAME ruby accepts, normalized the
#              way onigmo compares them (lowercase; ' ', '_' and '-' dropped).
#              X is "g<hex mask>" (a union of general categories), "f<bit>"
#              (a POSIX class), "s<index>" (a script), or "?" -- a name ruby
#              knows whose set is none of those (a block, an age, a derived
#              binary property). The runtime refuses a "?" as UNSUPPORTED and
#              a name missing from the list as INVALID, which is ruby's word.
#
# The candidate names are the ones in onigmo's name table
# (enc/unicode/<version>/name2ctype.h of a ruby checkout, passed as ARGV[0]);
# each one is asked of this ruby before it is listed.
#   uage_raw   "lo-hi:A" (hex): A = the age a codepoint was first assigned in,
#              an index into the ages sorted by version; a name "age=X" is
#              "a<index>" and matches first age <= X.
#   ublk_raw   "lo-hi:B" (hex): B = the block index; a block name is "b<index>".
# It prints the five `let` lines that go between the markers verbatim:
#   ruby tools/gen_uprop_table.rb path/to/name2ctype.h
hdr = File.read(ARGV[0] || abort("usage: gen_uprop_table.rb name2ctype.h"))

CPS = (0..0x10FFFF).reject { |c| (0xD800..0xDFFF).cover?(c) }
ALL = CPS.pack("U*")

# the set a pattern fragment matches, as a sorted codepoint list
def set_of(frag)
  re = Regexp.new("(?:#{frag})+")
  ALL.scan(re).join.codepoints
end

GCS = %w[Cn Cc Cf Co Cs Ll Lm Lo Lt Lu Mc Me Mn Nd Nl No Pc Pd Pe Pf Pi Po Ps Sc Sk Sm So Zl Zp Zs]
POSIX = %w[alpha alnum blank cntrl digit graph lower print punct space upper xdigit word ascii]

gc = Array.new(0x110000, 0)
gc_size = Array.new(GCS.size, 0)
GCS.each_with_index do |g, i|
  next if i == 0
  set_of("\\p{#{g}}").each { |c| gc[c] = i }
end
CPS.each { |c| gc_size[gc[c]] += 1 }

bits = Array.new(0x110000, 0)
posix_sets = POSIX.map { |nm| set_of("[[:#{nm}:]]") }
posix_sets.each_with_index { |s, b| s.each { |c| bits[c] |= (1 << b) } }

# scripts: the CR_ arrays from Common up to the first binary property, the
# order onigmo's table lists them in
arrays = hdr.scan(/static const OnigCodePoint CR_(\w+)\[\]/).flatten
scripts = arrays[arrays.index("Common")...arrays.index("Bidi_Control")]
sc = Array.new(0x110000, 0)
script_sets = {}
scripts.each_with_index do |nm, i|
  s = set_of("\\p{#{nm}}")
  s.each { |c| abort "script overlap at #{c}" if sc[c] != 0; sc[c] = i + 1 }
  script_sets[s] = i + 1
end
script_sets[CPS.select { |c| sc[c] == 0 }] = 0

def ranges(vals)
  rows = []
  lo = nil
  (0..0x110000).each do |cp|
    v = cp <= 0x10FFFF ? vals[cp] : 0
    if lo && v != vals[lo]
      rows << format("%X-%X:%X", lo, cp - 1, vals[lo])
      lo = nil
    end
    lo = cp if lo.nil? && v != 0
  end
  rows.join(",")
end

packed = Array.new(0x110000) { |c| gc[c] + 32 * bits[c] }
puts "let uprop_raw = \"#{ranges(packed)}\";"
puts "let usc_raw = \"#{ranges(sc)}\";"

names = hdr.scan(/sizeof\("([^"]+)"\)/).flatten.uniq

# ages: the version a codepoint was first assigned in, as an index into the
# ages sorted by version (1-based). \p{age=X} is cumulative -- every
# codepoint assigned in X or before -- so it is "first age <= X".
ages = names.grep(/\Aage=/).select { |nm| (Regexp.new("\\p{#{nm}}") rescue nil) }
            .sort_by { |nm| nm.sub("age=", "").split(".").map(&:to_i) }
age_first = Array.new(0x110000, 0)
ages.each_with_index do |nm, i|
  set_of("\\p{#{nm}}").each { |c| age_first[c] = i + 1 if age_first[c] == 0 }
end
age_ix = ages.each_with_index.to_h { |nm, i| [nm, i + 1] }
puts "let uage_raw = \"#{ranges(age_first)}\";"

# blocks: \p{In_Hiragana}, one per codepoint (In_No_Block is the rest)
blk = Array.new(0x110000, 0)
blk_ix = {}
names.grep(/\Ain/).each do |nm|
  next unless (Regexp.new("\\p{#{nm}}") rescue nil)
  s = set_of("\\p{#{nm}}")
  next if s.empty? || script_sets[s] || posix_sets.index(s)
  next if s.any? { |c| blk[c] != 0 }
  k = blk_ix.size + 1
  s.each { |c| blk[c] = k }
  blk_ix[nm] = k
end
puts "let ublk_raw = \"#{ranges(blk)}\";"

out = []
names.each do |nm|
  begin
    Regexp.new("\\p{#{nm}}")
  rescue RegexpError
    next
  end
  if age_ix[nm]
    out << "#{nm}:a#{age_ix[nm].to_s(16)}"
    next
  end
  if blk_ix[nm]
    out << "#{nm}:b#{blk_ix[nm].to_s(16)}"
    next
  end
  s = set_of("\\p{#{nm}}")
  if s.empty?
    out << "#{nm}:g0"
  elsif (b = posix_sets.index(s))
    out << "#{nm}:f#{b}"
  elsif (k = script_sets[s])
    out << "#{nm}:s#{k}"
  else
    gs = s.map { |c| gc[c] }.uniq
    if !gs.empty? && gs.sum { |g| gc_size[g] } == s.size
      out << "#{nm}:g#{gs.sum { |g| 1 << g }.to_s(16)}"
    else
      out << "#{nm}:?"
    end
  end
end
puts "let uname_raw = \"#{out.join(",")}\";"
