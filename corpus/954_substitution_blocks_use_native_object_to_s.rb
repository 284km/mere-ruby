# Native objects also implement to_s, without a Ruby method body.
Record954 = Struct.new(:number)
values = [Time.at(0).utc, /b/.match("abc"), Record954.new(3),
          Encoding::UTF_8, nil, 12, Rational(3, 2)]
values.each do |value|
  p ["x".sub(/x/) { value }, "xx".gsub(/x/) { value }]
  text = "xx"
  text.gsub!(/x/) { value }
  p text
end

class Stringified954
  def to_s = "converted"
end
class BadStringified954
  def to_s = 42
end
class Plain954; end

p "x".gsub(/x/) { Stringified954.new }
value = Plain954.new
p "x".sub(/x/) { value }.start_with?("#<Plain954:0x")
value = BadStringified954.new
p "x".sub(/x/) { value }.start_with?("#<BadStringified954:0x")

value = Time.at(0).utc
def value.to_s = "custom time"
p "x".sub(/x/) { value }
