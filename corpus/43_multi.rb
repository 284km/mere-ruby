a, b = 1, 2
puts a
puts b
a, b = b, a
puts a
puts b
p, q = [100, 200]
puts p
puts q
m, n = 5
puts m
puts n.nil?
c, d, e = 1, 2
puts c
puts e.nil?
first, *rest = 1, 2, 3, 4
puts first
puts rest.size
puts rest.sum
*init, last = 1, 2, 3, 4
puts last
puts init.size
head, *mid, tail = 1, 2, 3, 4, 5
puts head
puts mid.size
puts tail
one, two = [10, 20, 30]
puts one
puts two
