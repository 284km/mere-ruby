def f(x); x + 1; end
acc = 0
i = 0
while i < 200_000
  acc += f(i)
  i += 1
end
p acc
