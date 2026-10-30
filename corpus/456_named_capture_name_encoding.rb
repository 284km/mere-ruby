# A group name is a name in the encoding of its regexp. The same bytes read
# as another encoding are no name of its groups ([ruby-dev:48278] Bug #9903),
# and #names answers them in that encoding.
key = "\xb1\xb2".force_encoding(Encoding::EUC_JP)
r = /(?<#{key}>.*)/
m = r.match("xxx")
p m[key]
begin
  m[key.dup.force_encoding(Encoding::Shift_JIS)]
rescue IndexError => e
  p e.class
end
p m.names.map(&:encoding), r.names.map(&:encoding)
p m.names.first.bytes
m2 = "xxx".match(r)
p m2[key]
begin
  m2[key.dup.force_encoding(Encoding::Shift_JIS)]
rescue IndexError => e
  p e.class
end

# ASCII names are found whatever the key's encoding.
m3 = /(?<word>\w+)/.match("hi")
p m3["word"], m3["word".encode("UTF-16LE").encode("US-ASCII")], m3[:word]
