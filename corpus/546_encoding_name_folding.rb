# Case-insensitive names keep their canonical identity and codec behavior.
%w[UTF-8 US-ASCII ASCII-8BIT UTF-16LE UTF-16BE UTF-32LE UTF-32BE Windows-31J Shift_JIS EUC-JP ISO-8859-1].each do |name|
  expected = Encoding.find(name)
  [name, name.downcase, name.upcase, name.swapcase].each do |variant|
    actual = Encoding.find(variant)
    raise "encoding identity changed: #{variant}" unless actual.equal?(expected)
    text = 'Ruby 123'.encode(variant)
    raise "codec changed: #{variant}" unless text.encode('UTF-8') == 'Ruby 123'
  end
  puts expected.name
end
%w[BINARY ASCII CP932 SJIS].each do |name|
  puts Encoding.find(name.downcase).name
end
["", "UTF-8\0", "\xFF".b, "#{'a' * 256}utf-8"].each do |name|
  begin
    Encoding.find(name)
    puts 'unexpected encoding'
  rescue ArgumentError => error
    puts error.class
  end
end
puts 'encoding names preserved'
