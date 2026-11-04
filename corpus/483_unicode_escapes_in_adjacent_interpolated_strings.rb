# coding: us-ascii
# frozen_string_literal: true
accents = "" "[\u0300-\u034E]"
values = [
  "#{''}" "[\u00C0]" "#{accents}",
  "\u00C0" "#{accents}",
  "#{accents}" "\u00C0" "#{accents}",
  "prefix" "\u00C0" "suffix#{accents}",
  "#{'' # a multiline interpolation, as unicode_normalize/tables.rb writes it
  }" "[\u00C0]" "]?#{accents}+",
]
values.each { |value| p [value.codepoints, value.encoding.name, value.valid_encoding?] }

# Interpolated values retain their encoding. A Unicode escape must not make
# an incompatible binary value look like valid UTF-8.
binary = 255.chr(Encoding::ASCII_8BIT)
begin
  value = "\u00C0" "#{binary}"
  p [value.bytes, value.encoding.name, value.valid_encoding?]
rescue Encoding::CompatibilityError
  puts 'incompatible interpolation rejected'
end
