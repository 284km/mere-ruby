# A prepended wrapper reaches Range's native comparison, including at limits.
class Range
  alias_method :saved_case_equal, :===
end
module RangeCaseWrapper
  def ===(*arguments, &block)
    super
  end
end
Range.prepend(RangeCaseWrapper)
[[0..6, [0, 6, 7, -1, 3.5, nil, "6", 0..6]],
 [0...6, [0, 5, 6]], [..6, [-10, 6, 7]],
 [6.., [5, 6, 100]], ["a".."d", ["b", "cc", "z"]]].each do |range, values|
  values.each do |value|
    p [range, value, range === value, range.send(:===, value), range.saved_case_equal(value)]
  end
end
p [:case, case 6; when 0..6; :inside; else; :outside; end]
[[], [1, 2]].each do |arguments|
  [:===, :saved_case_equal].each do |method|
    begin
      (0..6).send(method, *arguments)
    rescue => error
      p [:arity, method, error.class, error.message]
    end
  end
end
class NativeRangeChild < Range
  def ===(value)
    super
  end
end
p [:child, NativeRangeChild.new(0, 6) === 6, NativeRangeChild.new(0, 6) === 7]
class ComparableRangeBound
  include Comparable
  attr_reader :value
  def initialize(value); @value = value; end
  def <=>(other); value <=> (other.is_a?(self.class) ? other.value : other); end
end
bounds = ComparableRangeBound.new(1)..ComparableRangeBound.new(5)
p [:objects, bounds === 3, bounds === 9, bounds.saved_case_equal(3)]

p [:object_values, bounds === ComparableRangeBound.new(3), bounds === ComparableRangeBound.new(9)]
class ObservedRangeBound
  include Comparable
  attr_reader :value
  def initialize(value); @value = value; end
  def <=>(other)
    ($range_native_comparisons ||= []) << [value, other.value]
    value <=> other.value
  end
end
observed = ObservedRangeBound.new(1)..ObservedRangeBound.new(5)
$range_native_comparisons = []
p [:observed, observed === ObservedRangeBound.new(3), $range_native_comparisons]
class RaisingRangeBound
  def <=>(other)
    raise 'actual comparison' unless other.is_a?(self.class)
    0
  end
end
begin
  (RaisingRangeBound.new..RaisingRangeBound.new) === 3
rescue => error
  p [:raised, error.class, error.message]
end

# A real native Range entry wins before a lower Ruby equality override.
module LowerRangeEquality
  def ===(other); :lower_module; end
end
Range.include(LowerRangeEquality)
p [:native_before_lower_module, (0..6) === 6]
# Replacing Range's entry removes that native target from super's remainder.
class Range
  def ===(other); super; end
end
p [:replacement_lower_module, (0..6) === 6]
module LowerRangeEquality
  remove_method :===
end
r = (1..3)
p [:replacement, r === 2, r === r, r === (1..3)]
p [:saved_native_after_replacement, r.saved_case_equal(2)]
class RangeReplacementChild < Range
  def ===(other); super; end
end
child = RangeReplacementChild.new(1, 3)
p [:replacement_child, child === 2, child === child, child === (1..3)]

class Range
  alias_method :===, :saved_case_equal
end
p [:restored_native_alias, r === 2, r === r]
