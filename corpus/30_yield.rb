def twice
  yield
  yield
end
twice { puts "hello" }

def with_value
  yield(10)
  yield(20)
end
with_value { |x| puts x * 2 }

def repeat(n)
  i = 0
  while i < n
    yield(i)
    i = i + 1
  end
end
repeat(3) { |k| puts "item " + k.to_s }

def sum_to(n)
  total = 0
  1.upto(n) { |x| total = total + x }
  total
end
puts sum_to(10)
