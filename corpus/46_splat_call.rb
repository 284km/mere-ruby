def add3(a, b, c)
  a + b + c
end
args = [1, 2, 3]
puts add3(*args)

def greet(name, greeting)
  greeting + ", " + name
end
parts = ["world", "hello"]
puts greet(*parts)

nums = [10, 20]
puts add3(5, *nums)

def collect(*xs)
  xs
end
a = [1, 2]
b = [3, 4]
puts collect(*a, *b).size
puts collect(0, *a, 9).join(",")
