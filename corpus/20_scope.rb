x = 100
def show
  x = 1
  x
end
puts show
puts x

def helper(n)
  n * 10
end
def compute(a)
  helper(a) + helper(a)
end
puts compute(3)

count = 5
def reset
  0
end
count = reset
puts count
