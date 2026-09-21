# A Time was epoch SECONDS and nothing else. #usec answered a hard-coded 0,
# #nsec / #subsec / #to_r / #ceil / #floor did not exist, `Time.at(x.5)` dropped
# the half, and two Times 300 ms apart subtracted to 0. The nanosecond rides
# beside the second now, and everything that reads a Time asks for it.
#
# Every value here was measured against the reference. Two are not what the
# name suggests: #subsec is an Integer 0 when there is no fraction (not (0/1)),
# and #iso8601(n) ZERO PADS to n digits, so .5 at 3 places is ".500".
#
# ⚠ This clock has no zone database -- it is UTC or nothing -- so everything
# below is built with Time.utc or marked .utc. That gap is in KNOWN_GAPS.md.

t = Time.utc(2020, 1, 2, 3, 4, 5)
u = Time.at(1577934245.5).utc

p [t.to_s, t.inspect, t.asctime, t.ctime, t.zone]
p t.to_a
p [t.tv_sec, t.tv_usec, t.tv_nsec, t.nsec, t.subsec, t.to_r]
p [u.usec, u.nsec, u.subsec, u.to_f, u.to_r, u.to_i]
p [u.to_s, u.inspect]
p [u.round.inspect, u.round(1).inspect, u.floor.inspect, u.ceil.inspect]
p [Time.at(1577934245.567).utc.floor(1).inspect, Time.at(1577934245.123).utc.ceil(1).inspect]
p [(t + 0.25).inspect, (u - 0.25).inspect, u - t]
p [u <=> t, t <=> u, u == t, u.eql?(u), u.eql?(t)]
p [Time.at(Rational(3, 2)).utc.inspect, Time.at(1577934245, 500000).utc.inspect]
p [t.iso8601, t.xmlschema, u.iso8601(3), u.iso8601(0), u.iso8601(9)]

# the struct-tm aliases answer respond_to? and reflection now, not just calls
p [t.respond_to?(:gmtime), t.respond_to?(:gmt?), t.respond_to?(:isdst)]
p Time.instance_method(:ctime) == Time.instance_method(:asctime)
p Time.instance_method(:gmtime) == Time.instance_method(:utc)
p Time.instance_method(:gmt_offset) == Time.instance_method(:utc_offset)

# ...and Thread's class arm answered NO Object method, because it was entered
# on the class and ended in `raise NoMethodError`.
p [Thread.nil?, Thread.frozen?, Thread.itself == Thread, Thread.respond_to?(:new)]
