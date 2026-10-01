# What stopped CRuby's own test files part-way -- a stack that ran out, a walk
# that never ended -- so that they printed no report and every test they had
# named read as passed. Each at the size the test uses.
require "rbconfig/sizeof"

# sprintf: a negative `*` width is left-justified, and INT_MIN's has no int
begin
  sprintf("%*s", RbConfig::LIMITS["INT_MIN"], "")
rescue ArgumentError => e
  p e.message
end
p sprintf("%*s|", -3, "a"), sprintf("%*d|", 4, 7)

# a struct that holds itself
k = Struct.new(:a)
o = k.new(1)
o.a = o
puts o.inspect.sub(/0x\h+/, "X")
S275 = Struct.new(:a, :b)
s = S275.new(1)
s.b = [s]
p s

# Range#step by a Rational
p (1..Float::INFINITY).step(1r).class, (1..Float::INFINITY).step(1r).first(3)
p (1..10.0).step(1r).first(3), (1..10).step(1r).first(3), (1..).step(1r).first(2)
p((1..3).step(1r) { |x| print x, " " })
begin
  (1..3).step(0r)
rescue ArgumentError => e
  p e.message
end

# an exclusive range that ends at int64's minimum
x = -2**63
p (x...x).to_a, (x...x).reverse_each.to_a, (x...x).map { 1 }, (x...x).each {}
p (x..x).to_a, ((x + 1)...x).to_a, (x...(x + 2)).to_a

# bsearch with bignum bounds
big = 2**100
p (-big..-123456789).bsearch { true }, (-big..-123456789).bsearch { |v| v >= -1000 }
p (-big..big).bsearch { |i| i >= 7 }, (-big..big).bsearch { |i| 7 <=> i }
ary = [3, 4, 7, 9, 12]
p (big...big + 5).bsearch { |i| ary[i - big] >= 6 }, (big...big + 5).bsearch { false }

# a #to_ary that answers a fresh array holding the object itself
def (a = Object.new).to_ary
  [self]
end
begin
  [a].join
rescue ArgumentError => e
  p e.message
end
b = [1]
p [b, b].join, [1, [2, [3, 4], 5]].join

# ARGF's readers take their keywords as keywords
path = "/tmp/mr275_#{$$}.txt"
File.write(path, "foo\nbar\n")
af = ARGF.class.new(path)
p af.readline(chomp: true), af.gets
af = ARGF.class.new(path)
af.each_line(chomp: true) { |l| p l }
p ARGF.class.new(path).readlines(chomp: true)
File.delete(path)
