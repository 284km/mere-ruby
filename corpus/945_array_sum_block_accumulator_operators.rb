class SumValue945
  attr_reader :value
  def initialize(value) = @value = value
  def +(other) = self.class.new(value + other.value)
end
values = [SumValue945.new(5), SumValue945.new(15)]
p values.sum(SumValue945.new(0)) { |v| v }.value
p values.sum(SumValue945.new(0)).value
[:with_block, :without_block].each do |kind|
  begin
    kind == :with_block ? values.sum { |v| v } : values.sum
  rescue TypeError => error
    p [kind, error.class]
  end
end
class CoercedSum945 < SumValue945
  def coerce(other) = [self.class.new(other), self]
end
p [CoercedSum945.new(1), CoercedSum945.new(2)].sum { |v| v }.value
p [1, 2, 3].sum { |v| break :stopped if v == 2; v }
p [1, 2, 3].sum { |v| next 5 if v == 2; v }
p [].sum(SumValue945.new(7)) { raise 'empty sum yielded' }.value
# Numeric fast paths ignore core + replacements, as Array#sum documents.
module IntegerPlus945
  def +(other) = 99
end
module FloatPlus945
  def +(other) = 99.0
end
Integer.prepend(IntegerPlus945)
Float.prepend(FloatPlus945)
p [1, 2, 3].sum { |v| v }
p [0.5, 1.5].sum { |v| v }
# Once a general accumulator has been used, numeric results keep Ruby dispatch.
class IntegerInitial945
  def +(other) = 10
end
class FloatInitial945
  def +(other) = 10.0
end
p [1, 2, 3].sum(IntegerInitial945.new) { |v| v }
p [1, 2, 3].sum(IntegerInitial945.new)
p [1.0, 2.0, 3.0].sum(FloatInitial945.new) { |v| v }
p [1.0, 2.0, 3.0].sum(FloatInitial945.new)
# Entering the general path through an addend must be sticky as well.
class ReturnsInteger945
  def coerce(other) = [IntegerInitial945.new, self]
end
p [ReturnsInteger945.new, 2, 3].sum { |v| v }
