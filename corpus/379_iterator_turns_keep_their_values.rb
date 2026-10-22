# Each turn of an iterator, of `loop`, and of a while runs in a region of its
# own, with its arguments made inside it. What a turn hands on -- a break or
# return value, a pair, an index, a value stored from the block -- comes out
# whole, and a loop of millions of turns does not hold the turns it is done with

p(3.times { |i| break i * 10 if i == 2 })
p 5.times { }
p(1.upto(4) { |i| next if i.odd? })
p(10.downto(7).map { |i| i })
p(1.step(10, 3) { |i| break [:stepped, i] if i > 5 })

kept = []
4.times { |i| kept << [i, i.to_s * 2] }
p kept

def first_big(xs)
  xs.each { |x| return x if x > 2 }
  :none
end
p first_big([1, 2, 3, 4])
p first_big([1])

h = {a: 1, b: 2, c: 3}
pairs = []
h.each { |pr| pairs << pr }
p pairs
p pairs.map(&:frozen?)
h.each { |k, v| pairs << [v, k] }
p pairs.last(3)
p(h.each { |k, v| break k if v == 2 })
p h.each_key.to_a, h.each_value.map { |v| v * 2 }
vals = []
h.each_value { |v| vals << v }
p vals

idx = []
%w[x y z].each_with_index { |s, i| idx << "#{s}#{i}" }
p idx
p(%w[x y z].each_with_index { |s, i| break [s, i] if i == 1 })

chars = []
"héllo".each_char { |c| chars << c }
p chars

n = 0
r = loop do
  n += 1
  next if n < 3
  break n * 100
end
p r
e = [1, 2].each
p(loop { e.next })
p(loop { raise StopIteration, "done" })

def in_method
  i = 0
  out = []
  while i < 5
    i += 1
    next if i == 2
    out << i
  end
  j = 0
  begin
    j += 1
  end while j < 3
  k = 0
  until k >= 4
    k += 2
  end
  [out, j, k, (while false; end)]
end
p in_method

def deep
  x = 0
  1000.times { |i| 10.times { |j| x += i * j } }
  x
end
p deep

big = 0
20_000.times { |i| a = [i, i + 1]; big += a.sum }
p big
