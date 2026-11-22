require "strscan"

["a\0b\nc", "\xff\0ab".b, "é日本x", "éx".encode("UTF-16LE"),
 "あｲx".encode("Windows-31J")].each do |text|
  boundaries = [0]
  text.each_char { |char| boundaries << boundaries.last + char.bytesize }
  [false, true].each do |fixed|
    scanner = StringScanner.new(text.dup, fixed_anchor: fixed)
    boundaries.reverse_each do |position|
      scanner.pos = position
      p [text.encoding.name, fixed, scanner.pos, scanner.charpos, scanner.rest_size]
    end
  end
end

[false, true].each do |fixed|
  text = "abcdef"
  scanner = StringScanner.new(text, fixed_anchor: fixed)
  scanner.pos = 2
  text.replace("é日x") # Same byte size, different character count.
  p [fixed, scanner.pos, scanner.charpos, scanner.check(/./), scanner.pos]
  text.replace("abcdef")
  scanner.pos = 2
  p [fixed, scanner.charpos, scanner.scan(/./), scanner.pos, scanner.charpos]
  text.force_encoding(Encoding::ASCII_8BIT)
  scanner.pos = 3
  p [fixed, scanner.charpos, scanner.scan(/./n), scanner.pos, scanner.charpos]
end

text = "head:body\n" * 32
scanner = StringScanner.new(text)
8.times do |index|
  scanner.pos = index * 10
  p [scanner.charpos, scanner.scan_until(/:/), scanner.charpos, scanner.pre_match, scanner.matched]
end

# Character positions must not trust a caller-defined String#length.
text = "éx"
def text.length = bytesize
scanner = StringScanner.new(text)
scanner.pos = 2
p scanner.charpos
