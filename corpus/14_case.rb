x = 2
case x
when 1
  puts "one"
when 2
  puts "two"
else
  puts "many"
end
lang = "ruby"
case lang
when "perl", "ruby"
  puts "scripting"
when "c"
  puts "compiled"
end
case 99
when 1
  puts "no"
end
case nil
when nil
  puts "nil matches"
end
