puts (1..5).to_a.size
(1..3).each { |i| puts i }
puts (1...4).to_a.size
r = 1..10
puts r.to_a.size
sum = 0
(1..100).each { |n| sum = sum + n }
puts sum
squares = (1..5).map { |x| x * x }
puts squares
