# Case mapping is context-independent in Ruby. Titlecase and case folding
# need their own mappings, including characters that map to themselves.
samples = ["ΣΣ Σ", "ßß", "ŉŉ", "ǅǈǋǲ", "ᾈᾀ", "և", "აᲐ", "Ꭰꭰ", "Iİıi"]
%w[UTF-8 UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |encoding|
  samples.each do |sample|
    source = sample.encode(encoding)
    results = [:upcase, :downcase, :capitalize, :swapcase].map do |method|
      result = source.public_send(method)
      [result.encode('UTF-8'), result.encoding.name, result.valid_encoding?]
    end
    p results
    p source.downcase(:fold).encode('UTF-8')
  end
  source = "Iİıi".encode(encoding)
  p [:upcase, :downcase, :capitalize, :swapcase].map { |m| source.public_send(m, :turkic).encode('UTF-8') }
  p "aΣß".encode(encoding).capitalize(:ascii).encode('UTF-8')
end

# Even an all-ASCII source can map to a non-ASCII byte in a single-byte
# encoding. Its bytes must be encoded back rather than copied from UTF-8.
%w[ISO-8859-1 ISO-8859-3 ISO-8859-9 Windows-1254 Windows-1257].each do |encoding|
  p "ßß".encode(encoding).capitalize.bytes
  source = 'Ii'.encode(encoding)
  p [:upcase, :downcase, :capitalize, :swapcase].map { |m| source.public_send(m, :turkic).bytes }
end

value = "ßΣ"
p [value.capitalize!.equal?(value), value, value.capitalize!]
p "Ꭰ".casecmp?("ꭰ")
%w[GBK CP936 CP949].each do |encoding|
  value = "\x80aZ".b.force_encoding(encoding)
  p [value.valid_encoding?, value.tr('a-z', 'A-Z').bytes,
     value.upcase.bytes, value.downcase.bytes, value.capitalize.bytes, value.swapcase.bytes]
end
value = "\x81A".b.force_encoding('GBK')
p [value.valid_encoding?, value.downcase.bytes]
p "\xff".b.force_encoding('GBK').valid_encoding?
