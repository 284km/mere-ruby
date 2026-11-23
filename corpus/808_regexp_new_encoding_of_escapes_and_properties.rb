# Regexp.new's encoding from what its source names:
# - in a US-ASCII string, escapes of bytes past 0x7F leave it US-ASCII and
#   not fixed (they read as UTF-8 only in a UTF-8 string);
# - in a UTF-8 string, a character property fixes it to UTF-8.
# A literal with only literal pieces interpolated is made the same way, and
# the VM runs a Regexp literal in any encoding.
def us(s) = s.dup.force_encoding("US-ASCII")
['\x80', 'a\xff', '\xc2\xa1', '\200', '\M-a', '[\x80-\xff]', 'a', '\x41'].each do |s|
  r = Regexp.new(us(s))
  p [s, r.encoding.to_s, r.fixed_encoding?]
end
['\p{Alpha}', '\P{Alpha}', '\p{^Alpha}', '\p{Hiragana}', '\xc2\xa1', 'a', '[[:alpha:]]', '\h'].each do |s|
  r = Regexp.new(s.dup.force_encoding("UTF-8"))
  p [s, r.encoding.to_s, r.fixed_encoding?]
end
r = /#{"\\p{Alpha}"}/
p [r.source, r.encoding, r.fixed_encoding?]
p [/\x80/n.encoding, /a/e.encoding, /a/s.encoding, /a/u.encoding, /#{"a"}/n.encoding]
