class Point
  def initialize(x, y); @x = x; @y = y; end
  def sum; @x + @y; end
end
acc = 0
i = 0
while i < 200_000
  acc += Point.new(i, i + 1).sum
  i += 1
end
p acc
