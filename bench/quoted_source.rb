# A quoted Ruby source string, not an Array allocation benchmark.
n = Integer(ENV.fetch("N", "100000"))
quote = ENV.fetch("QUOTE", '"')
text = "1," * n
value = eval(quote + text + quote)
raise "wrong literal" unless value == text
puts value.bytesize
