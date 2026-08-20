i = 0
acc = 0
while i < 200_000
  s = "value number #{i}"
  acc += s.length
  i += 1
end
p acc
