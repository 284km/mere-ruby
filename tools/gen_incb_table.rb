# Generates the Indic_Conjunct_Break ranges embedded in m_unicode.mere
# (ENC_INCB_TABLE markers), read from the pinned ruby source's
# enc/unicode/<version>/name2ctype.h -- ruby's regexp engine has the three
# sets for its own grapheme clusters (GB9c) but does not name them as a
# property, so they cannot be asked for the way tools/gen_gcb_table.rb asks.
# One letter per class: K=Linker N=Consonant E=Extend.
# Entries "lo-hi:K" hex, comma-separated, ascending.
#
#   ruby tools/gen_incb_table.rb /path/to/ruby-4.0.9
src = ARGV.fetch(0)
header = Dir[File.join(src, "enc/unicode/*/name2ctype.h")].max or abort "no name2ctype.h under #{src}"
text = File.read(header)
rows = []
{ "K" => "Linker", "N" => "Consonant", "E" => "Extend" }.each do |k, name|
  body = text[/static const OnigCodePoint CR_InCB_#{name}\[\] = \{(.*?)\};/m, 1] or abort "no CR_InCB_#{name}"
  nums = body.scan(/0x[0-9a-fA-F]+|\b\d+\b/).map { Integer(_1) }
  count = nums.shift
  abort "CR_InCB_#{name}: #{nums.size / 2} pairs, header says #{count}" unless nums.size == count * 2
  nums.each_slice(2) { |lo, hi| rows << [lo, hi, k] }
end
puts rows.sort.map { |lo, hi, k| format("%X-%X:%s", lo, hi, k) }.join(",")
