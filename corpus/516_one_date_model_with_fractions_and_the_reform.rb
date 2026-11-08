# Date and DateTime share one model now, date_core's: the local Julian Day,
# the seconds into it, the fraction of a second, the offset in seconds and
# the calendar reform (note 511's stage 3, test/date 111 -> 143/143). Before
# it, a Date had a day and nothing else, DateTime.new ignored its calendar,
# arithmetic rebuilt objects by name (so a subclass became Date) and a
# fraction of a second fell off on `+`. And three outside the library:
# strftime's width counts a negative year's sign (%5Y of -200 is -0200, Time
# as well), Marshal loads a Numeric subclass of the program's own
# (Date::Infinity) from an `o` record, and the 1.8 / 1.9.2 Marshal shapes of
# a DateTime keep their ajd on UTC.
require "date"

d = Date.new(2004, 9, 19) + Rational(1, 2)
p d, d.day_fraction, d.to_date.day_fraction, (d + Rational(1, 2)).jd
t = DateTime.new(2001, 2, 3, 4, 5, 6) + Rational(1, 86400 * 2)
p t.sec_fraction, t.strftime("%L %N %3N"), DateTime.jd(2451944, 4, 5, Rational(13, 2)).sec_fraction
p DateTime.new(2001, 2, 3, 4, 5, 6, Rational(32887, 86400)).strftime("%z %:z %::z %:::z"), DateTime.new(2001, 2, 3, 4, 5, 6, "+09:00").new_offset("-05:00")

p Date.new(1582, 10, 15) - 1, Date.new(1582, 10, 4) + 1, Date.new(1752, 9, 14, Date::ENGLAND) - 1, (Date.new(1582, 10, 10) rescue $!.class)
p Date.new(1582, 10, 4, Date::GREGORIAN), Date.new(1582, 10, 15, Date::JULIAN), Date.jd(Date::ITALY - 1).julian?, Date.jd(Date::ITALY).gregorian?
p Date.new(2001, 2, 3).new_start(Date::JULIAN), Date.new(2001, 2, 3).julian, Date.new(2001, 2, 3, Date::JULIAN).gregorian, Date.new(2001, 2, 3).start
p Date.ordinal(2001, 34), Date.commercial(2001, 5, 6), Date.new(1582, 10, 15).yday, Date.new(1582, 12, 31).yday, Date.new(1752, 12, 31, Date::ENGLAND).yday

i = Date::Infinity.new
p(i <=> Float::INFINITY, Float::INFINITY <=> i, -i <=> -Float::INFINITY, i <=> 1, Date.new(2001) <=> Date::Infinity.new)
d1 = DateTime.new(2013, 12, 6, 0, 0, Rational(1, 10000)); d2 = DateTime.new(2013, 12, 6, 0, 0, Rational(2, 10000))
p [d1 <=> d2, d1 <=> d1, d2 <=> d1, d1 == d2, d1 < d2]
p [Date.new(2001, 2, 3) <=> 2451943.5, Date.new(2001, 2, 3) === DateTime.new(2001, 2, 3, 12), Date.new(2001, 2, 3) === Date.new(2001, 2, 4), Date.new(2001, 2, 3) == DateTime.new(2001, 2, 3)]

class DateSub < Date; end
class DateTimeSub < DateTime; end
p [(DateSub.new + 1).class, (DateSub.new >> 1).class, DateSub.new.julian.class, (DateTimeSub.new - 1).class, DateSub.today.class, DateSub.new.next_day.class, Marshal.load(Marshal.dump(DateTimeSub.new(2001))).class]

p Date.new(2001, 2, 3).deconstruct_keys(nil), DateTime.new(2001, 2, 3, 4, 5, 6, "+09:00").deconstruct_keys([:hour, :min, :sec, :sec_fraction, :zone])
p Marshal.load("\x04\bU:\tDate[\bU:\rRational[\ai\x03\xCF\xD3Ji\ai\x00o:\x13Date::Infinity\x06:\a@di\xFA").then { |x| [x.ajd, x.start] }
p Marshal.load("\x04\bU:\rDateTime[\bU:\rRational[\al+\b\xC9\xB0\x81\xBD\x02\x00i\x02\xC0\x12U;\x06[\ai\bi\ro:\x13Date::Infinity\x06:\a@di\xFA").then { |x| [x.ajd, x.offset, x.start] }
p Marshal.load(Marshal.dump(Date::Infinity.new(-1))).then { |x| [x.class, x.infinite?, (x.d rescue $!.class)] }

p [-200, -5, 2001, 12345].map { |y| Date.new(y).strftime("%Y|%-Y|%5Y|%_Y|%3Y|%06Y|%C|%G") }, Time.utc(-200).strftime("%Y %5Y %_Y %C")
