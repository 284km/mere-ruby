# The iterable of a `for` must not swallow the loop's `do`, the same way a
# while condition must not. In `for y in 0...h do`, the bare `h` at the end of
# the range was taking the block -- chunky_png writes exactly that.
def h = 3
def w = 2

for y in 0...h do
  print y
end
puts

for y in 0..h do
  print y
end
puts

for y in 0...h
  print y
end
puts

a = [4, 5]
for y in a do
  print y
end
puts

for y in (0...h) do
  print y
end
puts

for i in [1, 2].map { |x| x * 2 } do
  print i
end
puts

# nested, and the loop variable survives the loop as in Ruby
for y in 0...h do
  for x in 0...w do
    print "#{y}#{x} "
  end
end
puts
p [y, x]

# A CONSUMED flow signal must not leave its internal message behind: the next
# real failure used to be reported as whatever that signal said.
def uses_return
  [1, 2].each { |v| return v }
end
p uses_return

begin
  nosuchmethod_here
rescue NameError => e
  puts e.class
end

def breaks_out
  [1, 2, 3].each { |v| break v if v == 2 }
end
p breaks_out

begin
  raise ArgumentError, "real cause"
rescue => e
  puts "#{e.class}: #{e.message}"
end
