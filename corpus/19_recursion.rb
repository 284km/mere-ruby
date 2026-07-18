def fact(n)
  if n <= 1
    return 1
  end
  n * fact(n - 1)
end
puts fact(5)
puts fact(10)

def fib(n)
  if n < 2
    return n
  end
  fib(n - 1) + fib(n - 2)
end
puts fib(10)

def sum_to(n)
  if n == 0
    return 0
  end
  n + sum_to(n - 1)
end
puts sum_to(100)
