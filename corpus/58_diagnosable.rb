# Adjacent string literals concatenate whichever quoting each one uses, and a
# line ending in `\` keeps that going.
p 'a ' 'b'
p 'a ' "b"
p "a " 'b'
p "a " "b"
x = 'one ' \
  "two #{1 + 1}"
p x
p 'q' 'r' 's'
p ['x' 'y']
p({'a' 'b' => 1})

# a bare `puts` takes a statement modifier, not an argument
puts unless false
puts if true
puts "shown"
puts("parens")
puts [1, 2]
puts

# Kernel#printf and a bare Kernel#print
printf("%02X-%s\n", 255, "x")
printf('%d', 7)
puts
print
print "a", "b"
puts

# an internal failure says what it was, and the FIRST cause wins over any
# later one on the way out
begin
  1.count
rescue Exception => e
  p [e.class.to_s, e.message.include?("count")]
end
begin
  raise ArgumentError, "a real one"
rescue Exception => e
  p [e.class.to_s, e.message]
end
p :done
