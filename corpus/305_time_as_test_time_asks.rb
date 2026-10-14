# Time as CRuby's test_time asks it (note 327): %:::z shows only as far as
# the first part that is not zero, a width after the colons or a fourth
# colon leaves the directive as written, %t and %n take a width; a string
# for Time.new names the part it is missing; "-0000" is UTC; a number is
# made exact through to_r only when it has to_int too, and its answer must
# be exact; 0.0001 seconds is 100 usec, not 99.
require 'delegate'
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
tz = Time.new(2001, 2, 3, 4, 5, 6, "+09:00")
t1 = Time.new(2001, 2, 3, 4, 5, 6, "+09:30")
t2 = Time.new(2001, 2, 3, 4, 5, 6, "-01:02:03")
t(1) { %w[%:::z %10:::z %_10:::z %-:::z %::10z %:0z %::::z].map { tz.strftime(_1) } + [t1.strftime("%:::z"), t2.strftime("%:::z")] }
t(2) { ["%3t", "%-3t", "%03n", "%^5t", "%_5n"].map { tz.strftime(_1) } }
t(3) { ["2020-12-25 00:56 +09:00", "2020-12-25 00 +09:00", "2020-12-25 00:56:17. +0900", "021-12-25 00:00:00 +09:00",
        "2020-12-25 00:56. +0900", "2020-12-25 00:56:9 +0900", "2020-1225", "2020-12", "2020-12-02 00:00:00 x y"].map { |s| (Time.new(s) rescue $!).inspect } }
t(4) { [Time.new("2021", in: "+01:00"), Time.new("2021-12-25+09:00", in: "-01:00"), Time.new("2020-12-25T00:56:17Z")] }
t(5) { g = Time.utc(2000); %w[UTC -0000 -00 -00:00:00 +0000 Z].map { [g.getlocal(_1).utc?, Time.new(2000, 1, 1, 0, 0, 0, _1).utc?] } }
t(6) { b = Time.utc(2000); [b + SimpleDelegator.new(1), b + SimpleDelegator.new(1.5), b + SimpleDelegator.new(Rational(1, 2))] }
class K305; def to_int = :no; def to_r = :no; end
t(7) { Time.at(K305.new) }
t(8) { Time.at("1") }
t(9) { [Time.at(0.0001).usec, Time.at(0.00001).usec, Time.at(0.000003).usec, Time.at(1.1).nsec] }
t(10) { u = Time.utc(2001, 4, 17, 19, 23, 17, 300000); [u.xmlschema(1.9), u.xmlschema(11), u.iso8601(3)] }
t(11) { Time.utc(2000).send(:initialize, 2013, 3, 14) }
t(12) { Time.gm(2000, 1, 1, 0, 0, 10_000_000_000_000_000_001.0, :foo, :foo) }
d = "\x04\bIu:\tTime\r\xEFF\x1C\x80\x00\x00\x00\x00\x06:\voffset".b
t(13) { [Marshal.load(d + "T").utc_offset == Marshal.load(d + "\"\x0ebadoffset").utc_offset, Marshal.load(d + "i\x06").utc_offset] }
