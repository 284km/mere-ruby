class MyError < StandardError
end

begin
  raise MyError, "specific"
rescue MyError => e
  puts "got MyError: " + e.message
end

begin
  raise MyError, "hier"
rescue StandardError => e
  puts "caught as StandardError: " + e.class.to_s
end

begin
  raise ArgumentError, "bad arg"
rescue TypeError
  puts "type"
rescue ArgumentError => e
  puts "arg: " + e.message
end

def check(n)
  raise ArgumentError, "negative" if n < 0
  n * 2
end
begin
  puts check(5)
  puts check(-1)
rescue ArgumentError => e
  puts "rejected: " + e.message
end
