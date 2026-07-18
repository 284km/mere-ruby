class Point
  def initialize(x, y)
    @x = x
    @y = y
  end
  def x
    @x
  end
  def y
    @y
  end
  def sum
    @x + @y
  end
  def to_s
    "(" + @x.to_s + ", " + @y.to_s + ")"
  end
end
p = Point.new(3, 4)
puts p.x
puts p.y
puts p.sum
puts p
puts p.to_s
q = Point.new(10, 20)
puts q.sum
