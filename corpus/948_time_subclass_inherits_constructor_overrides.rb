class TimeChild948 < Time; end
class TimeGrandchild948 < TimeChild948; end
class << TimeChild948
  alias_method :saved_now948, :now
end
native = TimeChild948.method(:now)
class << Time
  alias_method :original_now948, :now
  alias_method :original_at948, :at
  alias_method :original_utc948, :utc
  def now = at(1000)
end
[Time, TimeChild948, TimeGrandchild948].each do |klass|
  p [:now, klass.now.class, klass.now.to_i]
end
p [:bound_native, native.call.class, native.call.to_i > 2000]
p [:aliased_native, TimeChild948.saved_now948.class,
   TimeChild948.saved_now948.to_i > 2000]
class << Time
  def at(seconds, *args, **kw) = original_at948(seconds + 10, *args, **kw)
  def utc(*args) = original_utc948(*args) + 60
end
[Time, TimeChild948, TimeGrandchild948].each do |klass|
  p [:at, klass.at(3).class, klass.at(3).to_i]
  p [:utc, klass.utc(2020).class, klass.utc(2020).min]
  p [:gm_native, klass.gm(2020).min]
end
class << Time
  private :now
end
begin
  TimeChild948.now
rescue NoMethodError => error
  p [:private, error.class]
end
p [:send_private, TimeChild948.send(:now).class, TimeChild948.send(:now).to_i]
class << Time
  alias_method :now, :original_now948
  alias_method :at, :original_at948
  alias_method :utc, :original_utc948
  public :now
  remove_method :original_now948, :original_at948, :original_utc948
end
p [:restored, TimeChild948.now.class, TimeChild948.now.to_i > 2000]

# ActiveJob's argument round trip compares arrays containing ranges. The
# Time endpoints survive serialization as distinct objects with equal values.
first948 = Time.at(123, 456)
copy948 = Time.at(123, 456)
other948 = Time.at(124, 456)
[[first948.., copy948.., other948..],
 [first948..first948, copy948..copy948, copy948..other948],
 [..first948, ..copy948, ..other948]].each do |left, same, different|
  p [:range_container, left == same, [left] == [same],
     { range: left } == { range: same }, [[left]] == [[same]],
     [left] == [different], [left] == [Range.new(same.begin, same.end, true)]]
end

class RangeEndpoint948
  def initialize(value) = @value = value
  def <=>(other) = 0
  def ==(other) = @value == other.instance_variable_get(:@value)
end
left948 = RangeEndpoint948.new(1)..RangeEndpoint948.new(2)
same948 = RangeEndpoint948.new(1)..RangeEndpoint948.new(2)
other948 = RangeEndpoint948.new(1)..RangeEndpoint948.new(3)
p [:object_range, [left948] == [same948], [left948] == [other948],
   { range: [left948] } == { range: [same948] }]

# The non-allocating native-value check must still honor tagged Strings.
class RangeString948 < String
  def ==(other) = upcase == other.upcase
end
lower948 = RangeString948.new('a')..RangeString948.new('c')
upper948 = RangeString948.new('A')..RangeString948.new('C')
p [:string_range_override, lower948 == upper948, [lower948] == [upper948],
   {range: lower948} == {range: upper948}]
singleton948 = +'same'
def singleton948.==(other) = false
p [:singleton_string_override, [singleton948] == ['same']]
