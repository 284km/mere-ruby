a = []
a << 1
a << 2
a << 3
puts a.size
puts a
a.push(4)
puts a.last
puts a.pop
puts a.size
b = [1, 2, 3]
b.unshift(0)
puts b.first
puts b.size
c = [10, 20, 30]
c[1] = 99
puts c
puts c[1]
d = [1, 2]
d.concat([3, 4])
puts d.size
e = [5, 6, 7]
e.clear
puts e.size
puts e.empty?
