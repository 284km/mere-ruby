# What test/date found, first round (note 511's stage 3, "date 103"): the
# names and the printed forms are US-ASCII; a Date has no hour, zone or
# offset (DateTime has them); Marshal in ruby's shape ([nth, jd, df, sf, of,
# sg]) and the two older ones Date._load reads; initialize_copy takes any
# Date; DateTime.ordinal and .commercial with a time of day; a negative
# month counts back from December; a non-number is a TypeError; the string
# parsers take a limit; jisx0301; %^P is upper case; a width of 8192 or a
# year past 2048 digits is Errno::ERANGE; a negative year prints -0001.
# Two of the interpreter's own: a %w word list broken across lines and
# indented with tabs held a word of tabs, and a 100,000-digit String#to_i
# never returned (the digits are the bignum's own text).
require "date"

p %w(sunday? monday?
				 thursday?), %i(a	b
c)
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
n = ("1" + "0" * 100_000).to_i
p Math.log10(n), (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) < 20, "1_000".to_i, "12345678901234567890".to_i, "-00012".to_i, "99999999999999999999_1".to_i, "1__2".to_i, "_1".to_i

d = Date.new(2001, 2, 3)
dt = DateTime.new(2001, 2, 3, 4, 5, Rational(13, 2), "+09:00")
p [Date::MONTHNAMES[1], Date::ABBR_DAYNAMES[0], d.to_s, d.inspect, d.strftime, dt.to_s, dt.inspect, dt.zone].map(&:encoding).uniq
p d.respond_to?(:hour), d.respond_to?(:zone), d.respond_to?(:offset), dt.respond_to?(:hour), d.rfc3339, d.httpdate, d.rfc2822, d.to_datetime, dt.to_datetime.equal?(dt)
p d.marshal_dump, dt.marshal_dump, Marshal.load(Marshal.dump(d)) == d, Marshal.load(Marshal.dump(dt)) == dt, Marshal.load(Marshal.dump(dt)).class
p Date._load(Marshal.dump([Rational(4903887, 2), 0, Date::GREGORIAN])), Date._load(Marshal.dump([Rational(4903887, 2) + Rational(1, 2), true])).ajd
x = Date.allocate; x.marshal_load([0, 2451944, 0, 0, 0, 2299161.0]); p x
y = DateTime.allocate; y.marshal_load(dt.marshal_dump); p y, y == dt
f = Date.today.dup; f.freeze; p((f.marshal_load(f.marshal_dump) rescue $!.class))
c = DateTime.now; c.__send__(:initialize_copy, Date.new(2000, 1, 2)); p c.class, c.to_date, (d.__send__(:initialize_copy, 1) rescue $!.class)
p DateTime.ordinal(-4712, 1, 0, 0, 0, "+0900").offset, DateTime.ordinal(-1, -1, -1, -1, -1, 0), DateTime.commercial(1998, -1, -1, -1, -1, -1, 0), (DateTime.ordinal(2001, 365, 23, 59, 60, 0) rescue $!.class), (DateTime.commercial(1997, 52, 1, 23, 59, 60, 0) rescue $!.class)
p Date.civil(-1, -1, -1), DateTime.civil(-1, -1, -1, -1, -1, -1, 0), Date.ordinal(-1, -1).yday, Date.ordinal(-4712, 1.0), Date.commercial(1998, -1, -1)
o = Object.new
p [[Date, :new, [o]], [Date, :new, [1, o]], [Date, :new, [1, 1, o]], [Date, :jd, [o]], [Date, :ordinal, [o]], [Date, :commercial, [o]], [Date, :julian_leap?, [o]], [Date, :gregorian_leap?, [o]]].map { |k, m, a| (k.send(m, *a) rescue $!.class) }
p((Date._parse("1" * 1000) rescue $!.class), (Date._iso8601("1" * 1000) rescue $!.class), (Date._rfc3339("1" * 1000) rescue $!.class), (Date._xmlschema("1" * 1000) rescue $!.class), (Date._rfc2822("1" * 1000) rescue $!.class), (Date._rfc822("1" * 1000) rescue $!.class), (Date._httpdate("1" * 1000) rescue $!.class), (Date._jisx0301("1" * 1000) rescue $!.class))
p((Date.parse("1" * 1000) rescue $!.class), (Date.iso8601("1" * 1000) rescue $!.class), (Date.rfc3339("1" * 1000) rescue $!.class), (Date.xmlschema("1" * 1000) rescue $!.class), (Date.rfc2822("1" * 1000) rescue $!.class), (Date.httpdate("1" * 1000) rescue $!.class), (Date.jisx0301("1" * 1000) rescue $!.class), (DateTime.parse("1" * 1000) rescue $!.class))
p Date._parse("2001-02-03" + " " * 200, limit: 300)[:year], (Date._parse("2001-02-03" + " " * 200) rescue $!.message), Date._parse("Jan 1" + "0" * 100_000, limit: 100_010)[:mon]
p d.jisx0301, Date.new(1868, 10, 23).jisx0301, Date.new(1873, 1, 1).jisx0301, Date.new(1912, 7, 30).jisx0301, Date.new(1926, 12, 25).jisx0301, Date.new(1989, 1, 8).jisx0301, Date.new(2019, 5, 1).jisx0301, dt.jisx0301, dt.jisx0301(3)
p Time.new(2001, 2, 3, 16).strftime("%P %^P %#P %p %^p %#p"), d.strftime("%1000z").size, (d.strftime("%8192z") rescue $!.class), (d.strftime("%100000z") rescue $!.class), (Date.new(1 << 10000).strftime("%Y") rescue $!.class), Date.new(1 << 64).strftime("%Y")
p Date.civil(-1, 12, 31).to_s, DateTime.civil(-10, 1, 2, 3, 4, 5).to_s, Date.new(-4712).to_s
