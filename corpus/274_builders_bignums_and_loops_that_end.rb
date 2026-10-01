# Builtins that grow an answer piece by piece, bignums past what one word
# holds, and loops ruby ends: the cases that took CRuby's own test files past
# 6 GB, at sizes small enough to compare byte for byte.
a = (0...3000).to_a
s = a.join(",")
p s.size, s[0, 20], s[-20..]
p a.inspect.size, a.inspect.hash == a.to_s.hash, a.inspect[-12..]
h = {}
500.times { |i| h[i] = [i, i.to_s] }
p h.inspect.size, h.inspect[0, 30]
o = Object.new
o.instance_variable_set(:@a, a.take(5))
p o.inspect.sub(/0x\h+/, "X")
t = "x" * 5000
p t.gsub("x", "yz").size, t.gsub(/x/) { "ab" }.size, t.gsub(/x/, "x" => "q").count("q")
p ("\xA4" * 3000).encode("UTF-8", "ISO-8859-15") == "€" * 3000
p ("あ" * 2000).encode("UTF-16LE").bytesize, ("aé\x01" * 100).dump.size
p a.map(&:to_s).sum("").size, %w[a b c].sum("").encoding
p [1, [2, [3, "4"]]].join("-"), [1, 2].join.encoding
# bignums
x = 2**4000 + 12345
y = 3**1700 - 7
p (x * y).to_s.size, (x * y) / y == x, (x * y + 5) % y, x.divmod(10**30 + 7)
p x.to_s(16)[0, 20], x.to_s(2).size, x.bit_length, (x & (2**64 - 1)), (x | 1) - x, (x ^ y) ^ y == x
p x[0], x[13], x[4000], (-x)[3], Integer.sqrt(x * x) == x, Integer.sqrt(10**401)
p (2**64).pred, (-2**63).pred, (2**63 - 1).succ, (-2**63).to_s(2).size, (-2**63).to_s(36)
p((2 ** -0x4000000000000000 rescue $!.message))
p rand(10**30).class, Random.new(10**30).rand(10**25).class
p [0, 2**32, 2**40 + 3, 2**64].map { |sd| Random.new(sd).rand(1000) }
r = []
(-2**63..-2**63).reverse_each { |i| r << i }
(2**63 - 1..2**63 - 1).each { |i| r << i }
p r
# loops that end
sum = 0
for i in 1..10
  sum += i
  i -= 1
  redo if i > 0
end
p sum
trace_var(:$tv, proc { $tv *= 2 })
$tv = 5
p $tv
untrace_var(:$tv)
class SelfDumper
  def marshal_dump = dup
end
p((Marshal.dump(SelfDumper.new) rescue $!.message))
