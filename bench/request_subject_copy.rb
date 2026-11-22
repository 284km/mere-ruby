source = "a" * (2 * 1024 * 1024 - 1) + "z"
sum = 0
128.times do
  match = /az/.match(source)
  sum += match[0].bytesize
  match = /tiny/.match("tiny")
  sum += match[0].bytesize
end
p [source.bytesize, sum, source.frozen?]
