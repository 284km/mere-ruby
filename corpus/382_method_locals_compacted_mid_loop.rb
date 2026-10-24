# A method's locals live in a table whose old values pile up as a loop
# rewrites them; the collector now counts that table and compacts it, even
# while the method is running. What the method reads -- in the middle of an
# expression, through a closure, a block, a recursive call, define_method --
# is the value it wrote

def counter(n)
  i = 0
  s = 0
  while i < n
    s += i
    i += 1
  end
  [i, s]
end
p counter(300_000)

def mid_expression
  x = 10
  y = x + (GC.start; x = 20; x) + x
  [x, y]
end
p mid_expression

def closure_sees
  total = 0
  add = ->(v) { total += v }
  200_000.times { |i| add.(i % 3) }
  GC.start
  [total, add.(1)]
end
p closure_sees

def recurse(n, acc)
  return acc if n == 0
  t = 0
  20_000.times { |i| t = i }
  recurse(n - 1, acc + t)
end
p recurse(5, 0)

def strings_in_locals
  s = +""
  last = nil
  50_000.times { |i| last = "v#{i}"; s << "." if i % 10_000 == 0 }
  GC.start
  [last, s]
end
p strings_in_locals

class Acc
  define_method(:run) do |n|
    acc = []
    k = 0
    n.times { k += 1; acc << k if k % 50_000 == 0 }
    [k, acc]
  end
end
p Acc.new.run(200_000)

def many_locals
  a = b = c = d = e = 0
  100_000.times { |i| a = i; b = a + 1; c = b * 2; d = c - a; e = d + b }
  GC.start
  [a, b, c, d, e]
end
p many_locals
