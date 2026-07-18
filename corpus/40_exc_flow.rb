def risky(x)
  if x == 0
    raise ZeroDivisionError, "cannot divide"
  end
  100 / x
end

[2, 4, 0, 5].each do |n|
  begin
    puts risky(n)
  rescue ZeroDivisionError => e
    puts "skip: " + e.message
  end
end

def deep
  raise "from deep"
end
def middle
  deep
end
begin
  middle
rescue => e
  puts "propagated: " + e.message
end

def safe_div(a, b)
  a / b
rescue ZeroDivisionError
  -1
end
