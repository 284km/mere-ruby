a = [3, 1, 2]
puts a.first
puts a.last
puts a.sort
puts a.reverse
puts a.include?(2)
puts a.include?(9)
puts a.size
puts a.sum
puts a.min
puts a.max
puts a.index(2)
puts [1, 1, 2, 3, 3].uniq
puts [1, 2, 3, 4].join("-")
puts [1, 2, 3].map { |x| x * 10 }.sum
puts [1, 2, 3, 4, 5].select { |x| x > 2 }.size
puts [1, 2, 3, 4].reduce(0) { |acc, x| acc + x }
puts [1, 2, 3, 4].reduce { |acc, x| acc + x }
puts [5, 3, 8, 1].sort.first
puts a[0]
puts a[-1]
