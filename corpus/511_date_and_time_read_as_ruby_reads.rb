# Date._parse, Date._strptime and the format readers are ruby's own,
# ported (lib/date_parse_ext.rb is date_parse.c, lib/date_strptime_ext.rb is
# date_strptime.c with date_core.c's frag completion), and `require "time"`
# is ruby's lib/time.rb, which reads through them (note 511's stage 3:
# test/date 71 -> 111, test_time 22 -> 42). And two of the interpreter's
# own: Integer() and String#to_i of a long run of decimal digits are linear
# (a 100,000-digit year).
require "date"
require "time"

p Date._parse("Sat Aug 28 02:55:50 +09:00 1999"), Date._parse("H13.02.03"), Date._parse("1999-W33-6"), Date._parse("12/25/2000 7pm EST"), Date._parse("Jan 5th, '99", false)
p Date._parse("23:55:30.123456789 jst"), Date._parse("2001-02-03T04:05:06.07-08:30:15"), Date._parse("BC 300 Jan 1"), Date._parse("x"), Date._parse("")
p Date._iso8601("2001-033"), Date._rfc3339("2001-02-03T04:05:06+07:00"), Date._xmlschema("2001-02"), Date._rfc2822("Sat, 3 Feb 2001 04:05:06 UT"), Date._httpdate("Saturday, 03-Feb-01 04:05:06 GMT"), Date._jisx0301("R01.05.01")
p Date._strptime("2001-02-03", "%Y-%m-%d"), Date._strptime("Thu Jul 29 16:39:41 EST 1999", "%a %b %d %H:%M:%S %Z %Y"), Date._strptime("2006-06-01", "%G %V %w"), Date._strptime("x", "%Y"), Date._strptime("2001 33", "%Y %j")
p Date.parse("2001-02-03"), DateTime.parse("2001-02-03T04:05:06.5+09:00"), Date.strptime("2001 05 6", "%G %V %u"), DateTime.strptime("2001-02-03T04:05:06+0900"), Date.iso8601("2001-W05-6", Date::ITALY + 10).start
p DateTime.rfc2822("Sat, 3 Feb 2001 04:05:06 +0700"), Date.httpdate("Sat, 03 Feb 2001 04:05:06 GMT"), Date.jisx0301("H13.02.03"), (Date.parse("garbage") rescue $!.class), (Date.strptime("2001-13-01") rescue $!.class)
p (Date._parse(nil) rescue $!.class), (Date._parse(1) rescue $!.class), (Date._parse("1" * 1000) rescue $!.message), Date._parse("Jan 1" + "0" * 100_000, limit: 100_010).then { |h| [h[:mon], Math.log10(h[:year])] }

t = Time.parse("2001-02-03 04:05:06 +09:00")
p t, t.utc_offset, Time.iso8601("2001-02-03T04:05:06.123+07:00").subsec, Time.xmlschema("1985-04-12T23:20:50.52Z").iso8601(2), Time.rfc2822("Sat, 03 Feb 2001 04:05:06 -0000").utc?, Time.httpdate("Sat, 03 Feb 2001 04:05:06 GMT")
p Time.strptime("2001-02-03 04:05:06 +0900", "%Y-%m-%d %H:%M:%S %z"), Time.strptime("1000000000", "%s").utc, (Time.strptime("", "") rescue $!.class), (Time.iso8601("2001-02-03") rescue $!.class), (Time.parse("") rescue $!.class)
p Time.utc(2001, 2, 3, 4, 5, 6, 300_000).xmlschema(3), Time.utc(2001, 2, 3).rfc2822, Time.utc(2001, 2, 3).httpdate

p Integer("1" + "0" * 100_000).to_s.size, Integer("-" + "9" * 30), Integer("0001111", 10), Integer("1" * 25, 10), ("7" * 40).to_i, ("0" * 30 + "5").to_i, "1_2_3".to_i, (Integer("1" * 20 + "_") rescue $!.class)
