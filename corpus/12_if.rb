x = 10
if x > 5
  puts "big"
end
if x < 5
  puts "small"
else
  puts "not small"
end
if x == 1
  puts "one"
elsif x == 10
  puts "ten"
elsif x == 100
  puts "hundred"
else
  puts "other"
end
unless x == 3
  puts "not three"
end
if 0
  puts "zero is truthy"
end
y = 7
if x > 5 && y > 5
  puts "both"
end
if x > 5
  if y > 5
    puts "nested"
  end
end
