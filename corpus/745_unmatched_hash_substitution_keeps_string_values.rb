lookups = 0
replacement = Hash.new { lookups += 1; "unexpected" }
["a\0b".b, "あいう", ""].each do |input|
  [:sub, :gsub].each do |method|
    source = input.dup.freeze
    result = source.public_send(method, /\+|%\h\h/, replacement)
    p [method, result.bytes, result.encoding.name, result.equal?(source),
       source.frozen?, result.frozen?, lookups]
    result.replace("changed")
    p [source.bytes, result]
  end
end

source = "a\0b".b
result = source.gsub(/not-present/, {})
source.replace("gone")
GC.start
p [result.bytes, result.encoding.name]

# A later no-match must keep the replacements already assembled.
p "a+b".gsub(/\+|%\h\h/, "+" => " ")
p "a+b+c".sub(/\+/, "+" => " ")
p "aba".gsub(/a/, "a" => "")
p "ab".gsub(/(?=b)/, "" => "!")
p "".gsub(/\z/, "" => "!")

[:sub, :gsub].each do |method|
  /a/.match("a")
  source = "a\0b".b.freeze
  result = source.public_send(method, /not-present/, "replacement")
  p [result.bytes, result.encoding.name, result.equal?(source), result.frozen?, $~]
end
source = "abc".dup
p [source.gsub!(/not-present/, {}), source]
p [source.sub!(/not-present/, "replacement"), source]
p ["ab".gsub(/(a)(b)/, '\\2\\1'), $1, $2]
observed = []
replacement = Hash.new { |_, key| observed << [$&, $1]; key.upcase }
p ["a1 a2".gsub(/a(\d)/, replacement), observed]
