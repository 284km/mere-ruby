[10, 20, 30].each { |x| puts x }
words = ["a", "b", "c"]
words.each { |w| puts w }
nums = [1, 2, 3, 4, 5]
doubled = nums.map { |n| n * 2 }
puts doubled
evens = nums.select { |n| n % 2 == 0 }
puts evens
total = 0
nums.each { |n| total = total + n }
puts total
nums.each_with_index { |v, i| puts i.to_s + ":" + v.to_s }
