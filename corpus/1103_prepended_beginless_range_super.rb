module RangeSuper1103
  def count(...) = super
  def min(...) = super
  def max(...) = super
end
Range.prepend(RangeSuper1103)

def report_1103
  p yield
rescue => error
  p [error.class, error.message]
end

[(..3), (...3), (..3.0), (1..3), (1...3), (1..)].each do |range|
  [:count, :min, :max].each { |method| report_1103 { range.send(method) } }
end
report_1103 { (..3).count { true } }
report_1103 { (..3).min { |a, b| a <=> b } }
report_1103 { (..3).max { |a, b| a <=> b } }

# Replacing Range's own method removes the native entry at that position.
# Super must now reach Enumerable and its iteration error for a missing begin.
class Range
  def count(...) = super
  def min(...) = super
  def max(...) = super
end
[:count, :min, :max].each { |method| report_1103 { (..3).send(method) } }
