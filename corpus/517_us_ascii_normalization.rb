# Ruby's US-ASCII normalization path returns the receiver without decoding
# bytes or validating the form. The bang method still checks frozen receivers.
class NormalizationString < String
end

forms = [:nfc, :nfd, :nfkc, :nfkd, :unknown, nil, "nfc", Object.new]
[String, NormalizationString].each do |klass|
  ["", "abc\0", "\xff"].each do |bytes|
    forms.each do |form|
      string = klass.new(bytes).force_encoding("US-ASCII")
      original = string.dup
      normalized = string.unicode_normalize(form)
      raise "identity" unless normalized.equal?(string)
      raise "contents" unless normalized == original && normalized.encoding == original.encoding
      raise "class" unless normalized.class == klass
      raise "predicate" unless string.unicode_normalized?(form)
      raise "bang identity" unless string.unicode_normalize!(form).equal?(string)
      string.freeze
      raise "frozen identity" unless string.unicode_normalize(form).equal?(string)
      begin
        string.unicode_normalize!(form)
        raise "frozen bang accepted"
      rescue FrozenError
      end
    end
    puts [klass.name, bytes.unpack1("H*"), "ok"].join(":")
  end
end

# The bang method returns self even when another Unicode encoding is already
# normalized; both unchanged and changed values keep their original encoding.
["UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE"].each do |encoding|
  [:nfc, :nfd, :nfkc, :nfkd].each do |form|
    ["abc", "e\u0301"].each do |text|
      string = text.encode(encoding)
      expected = string.unicode_normalize(form)
      result = string.unicode_normalize!(form)
      raise "Unicode bang identity" unless result.equal?(string)
      raise "Unicode bang value" unless string == expected && string.encoding.name == encoding
    end
  end
  puts encoding
end

begin
  "abc".b.unicode_normalize
rescue Encoding::CompatibilityError
  puts "binary remains unsupported"
end
