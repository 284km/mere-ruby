def max(a, b)
  if a > b
    return a
  end
  b
end
puts max(3, 7)
puts max(10, 2)

def sign(n)
  if n > 0
    return "positive"
  elsif n < 0
    return "negative"
  end
  "zero"
end
puts sign(5)
puts sign(-3)
puts sign(0)

def early(x)
  return "small" if false
  while x > 0
    if x == 2
      return "hit two"
    end
    x = x - 1
  end
  "done"
end
puts early(5)
