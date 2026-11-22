class TimestampBoundary
  attr_reader :calls
  def initialize(answer)
    @answer = answer
    @calls = []
  end
  def <=>(time)
    @calls << time.class
    @answer
  end
end

time = Time.at(0)
[-1, 0, 1, -(2**100), 2**100].each do |answer|
  other = TimestampBoundary.new(answer)
  p [time <=> other, time < other, time <= other, time > other, time >= other]
  p other.calls
end

other = TimestampBoundary.new(nil)
p(time <=> other)
[:<, :<=, :>, :>=].each do |operator|
  begin
    time.public_send(operator, other)
  rescue => error
    p [error.class, error.message]
  end
end

raising = Object.new
raising.define_singleton_method(:<=>) { |_time| raise 'comparison callback' }
begin
  time < raising
rescue => error
  p [error.class, error.message]
end
