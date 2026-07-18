begin
  raise "boom"
rescue => e
  puts "caught: " + e.message
end

begin
  raise RuntimeError, "custom"
rescue => e
  puts e.message
  puts e.class
end

begin
  puts "before"
  raise "stop"
  puts "after (not reached)"
rescue
  puts "rescued"
end

x = begin
  10
rescue
  0
end
puts x
