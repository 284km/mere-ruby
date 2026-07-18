def take_all(*args)
  args.size
end
puts take_all(1, 2, 3)
puts take_all()
puts take_all(9)

def first_rest(a, *rest)
  puts a
  puts rest.size
end
first_rest(1, 2, 3, 4)
first_rest(10)

def surround(first, *mid, last)
  puts first
  puts mid.size
  puts last
end
surround(1, 2, 3, 4, 5)
surround(1, 2)

def sum_all(*nums)
  total = 0
  nums.each { |n| total = total + n }
  total
end
puts sum_all(1, 2, 3, 4, 5)
puts sum_all
