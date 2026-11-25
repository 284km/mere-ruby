# A timezone object changes its offset at epoch 1000, without system tzdata.
class MovingZone946
  attr_reader :calls
  def initialize(before, after)
    @before, @after, @calls = before, after, []
  end
  def utc_to_local(time)
    epoch = time.to_i
    @calls << epoch
    Time.at(epoch + (epoch < 1000 ? @before : @after)).utc
  end
  def local_to_utc(time) = Time.at(time.to_i - @before).utc
end

[[3600, 0], [3600, 1800], [0, 3600]].each do |before, after|
  zone = MovingZone946.new(before, after)
  original = Time.at(999, 750000).getlocal(zone)
  zone.calls.clear
  added = original + 1
  p [:lazy, added.to_i, zone.calls]
  p [:zone, added.zone.equal?(zone), zone.calls]
  p [:offset, added.utc_offset, zone.calls]
  p [:original, original.utc_offset]
  back = added - 1
  p [:back, back.utc_offset, back.subsec]
  p [:rounded, original.round.utc_offset]
  p [:floored, original.floor.utc_offset]
  p [:ceiled, original.ceil.utc_offset]
  p [:zero, (original + 0).utc_offset]
end

zone = MovingZone946.new(3600, 7200)
original = Time.at(999, 750000).getlocal(zone)
zone.calls.clear
copy = original.dup
p [:dup, copy.utc_offset, zone.calls]
copy = Time.at(original)
p [:at_lazy, zone.calls]
p [:at_offset, copy.utc_offset, zone.calls]
zone.calls.clear
copy = (original + 1).freeze
p [:frozen_lazy, zone.calls]
p [:frozen_offset, copy.utc_offset, copy.utc_offset, zone.calls]

[86400, -86400].each do |bad_offset|
  zone = MovingZone946.new(0, bad_offset)
  copy = Time.at(999).getlocal(zone) + 1
  p [:bad_lazy, copy.to_i]
  2.times do
    begin
      p [:bad_cached_offset, copy.utc_offset]
    rescue ArgumentError => error
      p [error.class, error.message]
    end
  end
  p [:retried, zone.calls]
end

# Fixed, fractional and UTC zones retain their exact original semantics.
[Rational(7201, 2), 3600, 'UTC'].each do |offset|
  time = Time.at(999, 750000).getlocal(offset)
  p [:fixed, (time + 1).utc_offset, time.round.utc_offset,
     (time + 1).utc?, (time + 1).zone]
end
