class Stack
  def initialize
    @items = []
  end
  def push(x)
    @items = @items + [x]
    self
  end
  def size
    @items.size
  end
  def to_s
    @items.to_s
  end
end
s = Stack.new
s.push(1)
s.push(2)
s.push(3)
puts s.size
puts s

class Rectangle
  attr_reader :w, :h
  def initialize(w, h)
    @w = w
    @h = h
  end
  def area
    @w * @h
  end
  def bigger_than(other)
    area > other.area
  end
end
r1 = Rectangle.new(3, 4)
r2 = Rectangle.new(2, 2)
puts r1.area
puts r2.area
puts r1.bigger_than(r2)
puts r2.bigger_than(r1)
