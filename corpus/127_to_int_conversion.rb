# An argument that is a COUNT or an INDEX accepts any object that answers
# #to_int -- Ruby asks for the conversion rather than requiring an Integer. Most
# places here already did; a sweep of them found three that did not, and each
# was wrong in its own way: setbyte ignored the object silently, Array.new made
# an empty array, and `*` refused with a TypeError.
o = Object.new
def o.to_int; 1; end

s = +"a00"
s.setbyte(o, "b".ord)
p s

p Array.new(o)
p Array.new(o, :x)
p "x" * o
p [1, 2] * o

# the ones that already worked, so the sweep has both halves
p [1, 2, 3][o]
p [1, 2, 3].first(o)
p [1, 2, 3].at(o)
p "abcdef"[o]
p "abcdef"[o, o]
p "abcdef".byteslice(o, o)
p (1..5).to_a[o]

# and an object that answers nothing is still refused
bad = Object.new
begin
  "x" * bad
rescue => e
  puts "#{e.class}: #{e.message}"
end
begin
  [1, 2, 3][bad]
rescue => e
  puts "#{e.class}: #{e.message}"
end
