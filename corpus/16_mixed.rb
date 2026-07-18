items = [1, 2, 3]
puts items
more = items + [4]
puts more == [1, 2, 3, 4]
h = {"a" => 1}
puts h
total = 0.0
step = 0.1
count = 0
while count < 3
  total = total + step
  count = count + 1
end
puts total
msg = "ok"
case msg
when "ok"
  result = 200
else
  result = 500
end
puts result
