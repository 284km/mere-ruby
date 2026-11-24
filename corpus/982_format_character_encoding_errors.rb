# Ruby 4.0.10 distinguishes US-ASCII/BINARY byte limits from other
# single-byte encodings when formatting an integer with %c.
%w[US-ASCII ASCII-8BIT ISO-8859-1 ISO-8859-2 Windows-1252].each do |encoding|
  [-1, 127, 128, 255, 256, 300].each do |number|
    begin
      result = "%c".dup.force_encoding(encoding) % number
      p [encoding, number, result.bytes]
    rescue ArgumentError, RangeError => error
      p [encoding, number, error.class.name, error.message]
    end
  end
end

# Dummy encodings use the same single-byte chr functions. Aliases must name
# their canonical encoding in the error, including CP65000 and ebcdic-cp-us.
%w[UTF-7 CP65000 UTF-16 UTF-32 ISO-2022-JP ISO-2022-JP-2
   ISO-2022-JP-KDDI CP50220 CP50221 IBM037 ebcdic-cp-us].each do |encoding|
  [-1, 0, 127, 128, 255, 256, 300, 0x3042, 0xFFFFFFFF, 0x100000000].each do |number|
    begin
      result = number.chr(encoding)
      p [encoding, number, result.encoding.name, result.bytes]
    rescue RangeError => error
      p [encoding, number, error.class.name, error.message]
    end
  end
end
