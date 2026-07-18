def fizzbuzz_word(n)
  if n % 15 == 0
    return "FizzBuzz"
  elsif n % 3 == 0
    return "Fizz"
  elsif n % 5 == 0
    return "Buzz"
  end
  n
end
i = 1
while i <= 15
  puts fizzbuzz_word(i)
  i = i + 1
end

def describe(x)
  case x
  when 0
    "zero"
  when 1, 2, 3
    "small"
  else
    "big"
  end
end
puts describe(0)
puts describe(2)
puts describe(99)
