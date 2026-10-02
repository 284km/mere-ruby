# Collections now run in the middle of a method or a block (on a stack of
# their own), so what a half-evaluated expression holds, what a builtin is
# still building, and the procs only a block tuple or a curried proc names
# must all survive one. GC.start inside a body collects right there.
require "strscan"

def half_done(xs)
  [xs.pop, (GC.start; xs.size), xs.map { |x| GC.start; x * 2 }]
end
p half_done([1, 2, 3])

def built(n)
  n.times.map { |i| s = "v#{i}"; GC.start if i % 7 == 0; s + "!" }.last(3)
end
p built(30)

s = StringScanner.new("hello world 42")
p [s.scan(/\w+/), (GC.start; s.scan(/\s+/)), s.scan(/\w+/), s.pos, s.rest]
m = /(\d+)/.match("a 42 b")
GC.start
p [m[1], m.begin(1), m.end(1), m.pre_match, m.post_match]

# a proc that only a curried one names, one only a &block passes along, and a
# lambda's identity and home
add = ->(a, b, c) { a + b + c }.curry
add1 = add[1]
GC.start
p add1[2][3]
def through(&b) = (GC.start; yield(4) + b.call(5))
p through { |x| x * 10 }
lam = lambda { |x| return x * 3; 0 }
keep = [lam]
GC.start
p [keep[0].call(7), keep[0].lambda?, keep[0].equal?(lam)]
def home
  [1, 2, 3].each { |x| GC.start; return x * 100 if x == 2 }
  :none
end
p home

# a define_method body's captured scope, and a block env reused across turns
class K
  base = "b"
  define_method(:k) { |x| GC.start; base + x.to_s }
end
p K.new.k(9)
acc = []
5.times { |i| t = [i, i.to_s]; GC.start if i.odd?; acc << t }
p acc

# a long loop whose garbage is collected while it runs, and the answer kept
def churn(n)
  total = 0
  n.times { |i| total += [i, i + 1].sum; "#{i}" * 3 }
  total
end
p churn(20_000)
