name = "Ruby"
puts "Hello, #{name}!"
puts "1 + 2 = #{1 + 2}"
x = 10
puts "x=#{x} sq=#{x * x}"
puts "empty#{""}end"
arr = [1, 2, 3]
puts "arr: #{arr}"
puts "size: #{arr.size}"
puts "#{arr.map { |n| n * 2 }.join(", ")}"
a = 3
b = 4
puts "#{a} + #{b} = #{a + b}"
class Point
  def initialize(x, y)
    @x = x
    @y = y
  end
  def to_s
    "(#{@x}, #{@y})"
  end
end
p = Point.new(5, 6)
puts "point is #{p}"
