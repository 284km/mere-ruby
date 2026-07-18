words = ["apple", "banana", "cherry"]
puts words.map { |w| w.upcase }.join(", ")
puts words.select { |w| w.length > 5 }.size
puts words.sort.first
nums = (1..10).to_a
puts nums.select { |n| n.even? }.sum
puts nums.map { |n| n * n }.reduce(0) { |a, b| a + b }
scores = {"alice" => 90, "bob" => 85, "carol" => 95}
puts scores.values.max
puts scores.keys.sort.join(" ")
top = scores.select { |k, v| v >= 90 }
puts scores.keys.count
sentence = "the quick brown fox"
puts sentence.split(" ").map { |w| w.capitalize }.join(" ")
