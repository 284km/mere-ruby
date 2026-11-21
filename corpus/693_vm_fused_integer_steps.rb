# A local and an Integer (or two locals) under a plain Integer operator, and
# the branch or the store after it: the VM answers those in one step while
# both are Integers and nothing watches or redefines the operator. Every
# other case is the instructions one by one, as before.

def fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)
p fib(15)

# past a Fixnum: the answer is a Bignum
big = 4611686018427387903
p big + 1, big * 3, -big - 10, big - -big

# not Integers: a Float, a String, nil
f = 1.5
p f + 1, f < 2, f * 2
s = "a"
p s + "b", s * 3
z = nil
begin
  z + 1
rescue NoMethodError => e
  p e.message
end

# loops: a compare and a branch, both ways round
i = 0
t = 0
while i < 10
  t += i
  i += 1
end
p t
j = 10
until j <= 0
  j -= 3
end
p j
k = 3
p(k == 3 ? :three : :other, k != 3 ? :no : :yes, k >= 3, k <= 2, k > 1)

# a block's += of a local further out: as a value and as a statement
sum = 0
r = [1, 2, 3].map { |x| sum += x }
p r, sum
cnt = 0
[4, 5].each { |x| cnt += x; nil }
p cnt
outer = 1
[1].each { [2].each { |y| outer += y } }
p outer

# an optional parameter read before its default ran
def opt(a, b = a + 1) = [a, b]
p opt(1), opt(1, 5)

# a TracePoint that watches the call sees it
seen = []
tp = TracePoint.new(:c_call) { |t| seen << t.method_id if t.method_id == :+ }
q = 1
tp.enable { q = q + 41 }
p q, seen.include?(:+)

# a refinement of the operator, used in this file
module Twice
  refine Integer do
    def -(o) = super(o) * 2
  end
end
using Twice
m = 10
p m - 3

# and Integer#+ redefined: every addition from here on is the new one
class Integer
  alias_method :__orig_plus, :+
  def +(o) = __orig_plus(o).__orig_plus(1000)
end
w = 1
p w + 1
v = 0
[1, 2].each { |x| v += x }
p v
