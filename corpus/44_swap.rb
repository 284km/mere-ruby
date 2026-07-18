def minmax(a, b)
  if a > b
    return b, a
  end
  return a, b
end
lo, hi = minmax(9, 3)
puts lo
puts hi
arr = [3, 1, 2]
arr = arr.sort
x, y, z = arr
puts x
puts y
puts z
i = 0
total = 0
[[1, 2], [3, 4], [5, 6]].each do |pair|
  aa, bb = pair
  total = total + aa + bb
end
puts total
