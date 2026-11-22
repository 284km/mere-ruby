# Existing primitive undef bypass, independently reproduced on main/parent.
module UndefRangeWrapper
  def ===(other); super; end
end
Range.prepend(UndefRangeWrapper)
class Range
  undef_method :===
end
range = (1..3)
begin
  p [:operator, range === 2]
rescue => error
  p [:operator, error.class]
end
begin
  p [:method, range.send(:===, 2)]
rescue => error
  p [:method, error.class]
end
