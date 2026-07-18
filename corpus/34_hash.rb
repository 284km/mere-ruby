h = {"a" => 1, "b" => 2, "c" => 3}
puts h["a"]
puts h["b"]
puts h.size
puts h.keys.size
puts h.values.sum
puts h.key?("a")
puts h.key?("z")
puts h.include?("c")
h.each { |k, v| puts k + "=" + v.to_s }
puts h.keys.sort.join(",")
puts({}.empty?)
puts h.empty?
