a = [1, 2, 3]
b = a
a << 4
puts b.size
puts b.last

def add_item(arr, x)
  arr << x
end
list = [1]
add_item(list, 2)
add_item(list, 3)
puts list.size
puts list

result = []
[1, 2, 3].each do |n|
  result << n * 10
end
puts result
puts result.sum

def build
  items = []
  [1, 2, 3, 4].each { |x| items << x if x.even? }
  items
end
puts build.join(",")
