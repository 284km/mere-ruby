# Decimal fast-path boundaries, permissive termination and underscore rules.
inputs = ["", "_12", "12_", "12__34", "12_34", "  +12_34tail", "-0_01",
          "9" * 18, "9" * 19, "0" * 25 + "42", "1" * 25 + "__99",
          "-" + "2_" * 30 + "3", "0d" + "3" * 25, "0x" + "a" * 25]
inputs.each do |s|
  p [s, s.to_i, s.to_i(0), s.to_i(10), s.to_i(16)]
end

# Keep the output small while checking every digit of a long result.
s = "1234567890" * 10_000
["", "-", "+"].each do |sign|
  text = (sign + s).to_i.to_s
  expected = (sign == "-" ? "-" : "") + s
  p [text.length, text == expected]
end
with_separators = ("12345_" * 20_000) + "67890"
text = with_separators.to_i.to_s
p [text.length, text == ("12345" * 20_000 + "67890")]
GC.start
p text.end_with?("67890")
