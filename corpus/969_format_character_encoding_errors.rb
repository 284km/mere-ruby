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
