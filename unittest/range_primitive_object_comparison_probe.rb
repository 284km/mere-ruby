# Existing direct Range comparison gap, independent of the native super entry.
class RangeComparisonProbe
  include Comparable
  attr_reader :value
  def initialize(value); @value = value; end
  def <=>(other); value <=> (other.is_a?(self.class) ? other.value : other); end
end
range = RangeComparisonProbe.new(1)..RangeComparisonProbe.new(5)
begin
  p [:direct, range.cover?(3), range === 3]
rescue => error
  p [:direct, error.class]
end
