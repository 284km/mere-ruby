# Compares MereDateStrptime (date_strptime_port.rb) with the reference ruby's
# Date._strptime / Date.strptime / DateTime.strptime.
#
#   /Users/284km/.rbenv/versions/4.0.9/bin/ruby check_strptime.rb
#
# Part 1 runs ruby's own test/date/test_date_strptime.rb in a child process
# with Date/DateTime's _strptime and strptime wrapped to record every
# argument list they get (the big tables and the 366-day loops included),
# then replays each one through the port. Part 2 is generated: strftime round
# trips of random Dates/DateTimes under many formats, mutated (malformed)
# strings, random directive soups, zone strings, and calendar starts.
# For strptime the compared value is [jd, df, sf, of] (jd/df as UTC).
require "date"
require "rbconfig"
require "tmpdir"
require_relative "../../lib/date_strptime_ext"

TEST_FILE = "/Users/284km/src/github.com/ruby/ruby-4.0.9/test/date/test_date_strptime.rb"

# ------------------------------------------------------------ recording

def record_test_file_calls
  out = File.join(Dir.tmpdir, "strptime_rec_#{$$}.bin")
  hook = <<~RUBY
    require "date"
    $__rec = []
    module MereRec
      def _strptime(*a) = ($__rec << [:parse, name, a.map { |x| x.is_a?(String) ? x.dup : x }]; super)
      def strptime(*a) = ($__rec << [:new, name, a.map { |x| x.is_a?(String) ? x.dup : x }]; super)
    end
    Date.singleton_class.prepend(MereRec)
    DateTime.singleton_class.prepend(MereRec)
    at_exit { File.binwrite(#{out.dump}, Marshal.dump($__rec)) }
    load #{TEST_FILE.dump}
  RUBY
  log = IO.popen([RbConfig.ruby, "-e", hook, "--", "--verbose=silent"], err: [:child, :out], &:read)
  status = $?
  raise "recording failed:\n#{log}" unless File.exist?(out)
  recs = Marshal.load(File.binread(out))
  File.delete(out)
  [recs, status.success?, log]
end

# ------------------------------------------------------------ comparing

def outcome
  [:ok, yield]
rescue Date::Error => e
  [:err, Date::Error, e.message]
rescue StandardError => e
  [:err, e.class, e.message]
end

def same_value?(a, b)
  return false unless a.class == b.class && a == b
  return a.encoding == b.encoding if a.is_a?(String)
  true
end

def same_hash?(a, b)
  return a.nil? && b.nil? if a.nil? || b.nil?
  return false unless a.keys.sort == b.keys.sort
  a.all? { |k, v| same_value?(v, b[k]) }
end

def same_outcome?(x, y)
  return false unless x[0] == y[0]
  return x[1] == y[1] && x[2] == y[2] if x[0] == :err
  if x[1].is_a?(Hash) || y[1].is_a?(Hash) || x[1].nil? || y[1].nil?
    same_hash?(x[1], y[1])
  else
    x[1] == y[1] && x[1].map(&:class) == y[1].map(&:class)
  end
end

def ruby_quad(d)
  return nil if d.nil?
  return [d.jd, 0, 0, 0] unless d.is_a?(DateTime)
  u = d.new_offset(0)
  sf = u.sec_fraction * 1_000_000_000
  sf = sf.numerator if sf.is_a?(Rational) && sf.denominator == 1
  [u.jd, u.hour * 3600 + u.min * 60 + u.sec, sf, (d.offset * 86400).to_i]
end

$counts = Hash.new(0)
$kinds = Hash.new { |h, k| h[k] = Hash.new(0) }
$mismatches = Hash.new { |h, k| h[k] = [] }

def tally(group, ref)
  $kinds[group][ref[0] == :err ? :error : ref[1].nil? ? :nil : :value] += 1
end

def check_parse(group, klass, args)
  $counts[group] += 1
  ref = outcome { klass._strptime(*args) }
  tally(group, ref)
  a = args.dup
  a[1] = (klass <= DateTime ? "%FT%T%z" : "%F") if a.size == 1
  mine = outcome { MereDateStrptime._strptime(*a) }
  return if same_outcome?(ref, mine)
  $mismatches[group] << ["#{klass}._strptime", args, ref, mine]
end

def check_new(group, klass, args)
  $counts[group] += 1
  ref = outcome { ruby_quad(klass.strptime(*args)) }
  tally(group, ref)
  dt = klass <= DateTime
  mine = outcome do
    q = dt ? MereDateStrptime.datetime_strptime(*args) : MereDateStrptime.date_strptime(*args)
    raise Date::Error, "invalid date" if q.nil?
    q
  end
  return if same_outcome?(ref, mine)
  $mismatches[group] << ["#{klass}.strptime", args, ref, mine]
end

# ------------------------------------------------------------ part 1

recs, test_ok, test_log = record_test_file_calls
uniq = recs.uniq
uniq.each do |kind, kname, args|
  klass = Object.const_get(kname)
  if kind == :parse
    check_parse(:test_file_parse, klass, args)
  else
    check_new(:test_file_new, klass, args)
  end
end

# ------------------------------------------------------------ part 2

rng = Random.new(20261107)

FORMATS = [
  "%Y-%m-%d", "%F", "%c", "%x", "%X", "%D", "%v", "%+", "%r", "%R", "%T",
  "%a %b %e %H:%M:%S %Z %Y", "%A, %B %d, %Y", "%a, %d %b %Y %H:%M:%S %z",
  "%G-W%V-%u", "%G %V %w", "%Y %U %w", "%Y %U %u", "%Y %W %w", "%Y %W %u",
  "%C %y %U %w", "%C %g %V %u", "%C%y%m%d", "%y%m%d", "%Y%m%d", "%Y%j",
  "%Y-%j", "%j", "%d", "%b", "%Y", "%b %Y", "%H:%M", "%a %H:%M", "%V", "%u",
  "%s", "%Q", "%s %N", "%Q %N", "%s %z", "%Q %z", "%FT%T%z", "%FT%T%:z",
  "%FT%T%::z", "%FT%T%:::z", "%FT%T.%N%z", "%FT%T.%L%:z", "%FT%T,%3N",
  "%I:%M:%S %p", "%l:%M %P", "%k%M%S", "%l%M%S", "%H%M%S%L", "%H%M%S%N",
  "%Ey", "%EY", "%Ec", "%EC%Ey", "%Ex", "%EX", "%Od", "%Oe", "%OH", "%OI",
  "%Om", "%OM", "%OS", "%Ou", "%OU", "%OV", "%Ow", "%OW", "%Oy",
  "%e.%m.%Y", "%d/%b/%Y:%H:%M:%S %z", "%h %e %Y", "%n%Y%t%m", "%%%Y%%",
  "%Y%m%d%H%M%S", "%Y%m%dT%H%M%S%z", "%A %B %d %y", "%d-%b-%y", "%B%t%d,%n%y",
  "%g%V%u", "%G%V%u", "%Y9%m9%d", "%Y %m %d %H %M %S %N", "%C %y %j %H %M %S",
  "%c %Z", "%x %X", "%D %T %Z", "%Y-%m-%dT%H:%M:%S%Z", "%L", "%N", "%3N",
  "%Y%m%e", "%a%d%b%y%H%p%Z", "%U-%w", "%W-%w", "%V-%u", "%G-%V", "%Y-%U",
  "%Y-%W", "%m/%d/%Y", "%H:%M:%S", "%I%p", "%A", "%B", "%y", "%C", "%G",
  "%e-%b-%Y %k:%M", "%Y.%j", "%:z", "%z", "%Z", "%s%L", "%Q%z",
]
STRF_ONLY = [ # strftime with flags/widths, parsed with the plain format
  ["%-m/%-d/%Y", "%m/%d/%Y"], ["%_m/%_d/%Y", "%m/%d/%Y"], ["%10Y-%m-%d", "%Y-%m-%d"],
  ["%^a %^b %d %Y", "%a %b %d %Y"], ["%#b %d", "%b %d"], ["%-H:%M", "%H:%M"],
  ["%_H:%M", "%H:%M"], ["%-I %p", "%I %p"], ["%6N", "%N"], ["%12N", "%N"],
  ["%-j", "%j"], ["%_y", "%y"], ["%-y", "%y"], ["%_3d", "%d"], ["%010s", "%s"],
]

def rand_date(rng)
  y = case rng.rand(10)
      when 0 then rng.rand(-5000..1581)
      when 1 then rng.rand(1582..1930)
      when 2 then rng.rand(-99_999..99_999)
      when 3 then rng.rand(10_000..10**7) * (rng.rand(2).zero? ? 1 : -1)
      else rng.rand(1900..2100)
      end
  Date.new(y, 1, 1) + rng.rand(366)
end

def rand_datetime(rng)
  d = rand_date(rng)
  off = case rng.rand(4)
        when 0 then 0
        when 1 then Rational(rng.rand(-12..14), 24)
        when 2 then Rational(rng.rand(-48..56) * 15, 1440)
        else Rational(rng.rand(-86_399..86_399), 86_400)
        end
  sf = case rng.rand(3)
       when 0 then 0
       when 1 then Rational(rng.rand(1000), 1000)
       else Rational(rng.rand(10**9), 10**9)
       end
  DateTime.new(d.year, d.mon, d.mday, rng.rand(24), rng.rand(60), rng.rand(60) + sf, off)
rescue Date::Error
  DateTime.new(2001, 2, 3, 4, 5, 6, 0)
end

MUT_CHARS = "0123456789 -+:.,/aApPmMTZz%xXEOW\t\n"
def mutate(s, rng)
  return s + "1" if s.empty?
  i = rng.rand(s.size)
  case rng.rand(6)
  when 0 then s[0, i] + s[i + 1..]
  when 1 then s[0, i] + MUT_CHARS[rng.rand(MUT_CHARS.size)] + s[i..]
  when 2 then s[0, i] + MUT_CHARS[rng.rand(MUT_CHARS.size)] + s[i + 1..]
  when 3 then s[0, i]
  when 4 then s + s[i..]
  else s.swapcase.sub(/\d/) { |d| ((d.to_i + 5) % 10).to_s }
  end
end

roundtrip = []
600.times do
  obj = rng.rand(2).zero? ? rand_datetime(rng) : rand_date(rng)
  f = FORMATS[rng.rand(FORMATS.size)]
  s = begin obj.strftime(f) rescue next end
  roundtrip << [s, f]
end
300.times do
  sf, pf = STRF_ONLY[rng.rand(STRF_ONLY.size)]
  roundtrip << [rand_datetime(rng).strftime(sf), pf]
end
[DateTime.new(2001, 2, 3, 4, 5, 6.789r, "+09:00"), Date.new(1999, 12, 31)].each do |o|
  FORMATS.each { |f| roundtrip << [o.strftime(f), f] }
end
roundtrip.each do |s, f|
  check_parse(:gen_roundtrip_parse, Date, [s, f])
  check_new(:gen_roundtrip_date, Date, [s, f])
  check_new(:gen_roundtrip_datetime, DateTime, [s, f])
end

malformed = []
roundtrip.sample(500, random: rng).each do |s, f|
  m = s
  (1 + rng.rand(3)).times { m = mutate(m, rng) }
  malformed << [m, f]
end
DIRECTIVES = %w[%a %A %b %B %h %c %C %d %e %D %F %g %G %H %I %j %k %l %L %m %M %n %N %p %P
                %Q %r %R %s %S %t %T %u %U %V %w %W %x %X %y %Y %z %Z %+ %% %v %:z %::z
                %:::z %::::z %Ec %EC %Ex %EX %Ey %EY %Od %Oe %OH %OI %Om %OM %OS %Ou %OU
                %OV %Ow %OW %Oy %Ea %Oa %EH %Oj %q %E %O %: %5 %_]
300.times do
  f = Array.new(1 + rng.rand(4)) { rng.rand(4).zero? ? MUT_CHARS[rng.rand(MUT_CHARS.size)] : DIRECTIVES[rng.rand(DIRECTIVES.size)] }.join
  s = Array.new(rng.rand(14)) { MUT_CHARS[rng.rand(MUT_CHARS.size)] }.join
  malformed << [s, f]
  malformed << [f, f]
end
malformed.each do |s, f|
  check_parse(:gen_malformed_parse, Date, [s, f])
  check_new(:gen_malformed_date, Date, [s, f])
  check_new(:gen_malformed_datetime, DateTime, [s, f])
end

ZONE_STRINGS = [
  "EST", "est dst", "EST  DST", "Eastern Standard Time", "Mountain Daylight Time",
  "E. Australia Standard Time", "E.  Australia  Standard  Time", " EST", "GMT+9",
  "GMT+09:30", "UTC-03:30", "ut+9", "utc+0930", "+0900", "-09", "+9", "+123",
  "+12345", "+1234567", "+3.5", "+3,25", "-3.75", "+12.3456789", "+0.12345678",
  "+0.12345650", "+0.12345750", "-0.00000005", "+23:59:59", "+24:00", "+23:60",
  "Z", "z", "jst", "XYZ", "foo bar", "cest", "EST5EDT", "Central Daylight Time",
  "Pacific Time", "pst time", "gmt", "utc", "UTC+", "GMT-", "+99999999999999999999:00",
  "+3.5:30", "-11:5:7", "a", "Y", "nzdt dst", "Mid-Atlantic Standard Time",
  "W. Europe Standard Time", "west asia standard time", "india standard time x",
]
ZONE_STRINGS.each do |z|
  ["%Z", "%z", "%Z|", "%H %Z"].each do |f|
    s = f.include?("%H") ? "12 #{z}" : (f.end_with?("|") ? "#{z}|" : z)
    check_parse(:gen_zone_parse, Date, [s, f])
    check_new(:gen_zone_datetime, DateTime, [s, "%H %Z"]) if f.include?("%H")
  end
  check_parse(:gen_zone_parse, Date, ["#{z} rest", "%Z"])
end

STARTS = [Date::ITALY, Date::ENGLAND, Date::JULIAN, Date::GREGORIAN, 2299170, 0, Float::NAN]
200.times do
  d = rand_date(rng)
  f = ["%Y-%m-%d", "%Y-%j", "%G-W%V-%u", "%Y %U %w", "%Y %W %u", "%C %y %m %d", "%s"][rng.rand(7)]
  s = d.strftime(f)
  sg = STARTS[rng.rand(STARTS.size)]
  check_new(:gen_start_date, Date, [s, f, sg])
  check_new(:gen_start_datetime, DateTime, [s, f, sg])
end
(Date.new(1582, 9, 25)..Date.new(1582, 10, 30)).each do |d|
  [Date::ITALY, Date::JULIAN, Date::GREGORIAN].each do |sg|
    %w[%Y-%m-%d %Y-%j].each { |f| check_new(:gen_reform, Date, [d.strftime(f), f, sg]) }
  end
end
(1..31).each { |dd| check_new(:gen_reform, Date, ["1582-10-%02d" % dd, "%F"]) }
(1..31).each { |dd| check_new(:gen_reform, Date, ["1752-09-%02d" % dd, "%F", Date::ENGLAND]) }

MISC = [
  [Date, ["2001-02-03".encode("UTF-16LE")]], [Date, [1]], [Date, ["2001", 1]],
  [Date, ["2001-02-03".encode("EUC-JP")]], [Date, ["EST\xff".b, "%Z"]],
  [Date, ["2001\xff".b, "%Y"]], [Date, ["日本 2001", "日本 %Y"]],
  [Date, ["2001-02-03 ほげ"]], [Date, ["Sat EST ほ", "%a %Z ほ"]],
  [DateTime, ["2001-02-03T04:05:06+07:00"]], [DateTime, ["2001-02-03T04:05:06"]],
  [Date, []], [DateTime, []],
]
MISC.each do |k, a|
  check_parse(:gen_misc, k, a) unless a.empty?
  check_new(:gen_misc, k, a)
end

# new_by_frags / complete_frags on hand-made field sets, today pinned to
# Date.today, against strptime of the same fields through the public API
today = Date.today
DIR_OF = { mday: "%d", mon: "%m", yday: "%j", wday: "%w", hour: "%H", min: "%M", cweek: "%V",
           cwday: "%u", wnum0: "%U", wnum1: "%W", year: "%Y", cwyear: "%G", seconds: "%Q", offset: "%z" }
[{ mday: 13 }, { mon: 3 }, { yday: 73 }, { wday: 0, hour: 1 }, { cweek: 11 }, { cwday: 6 },
 { wnum0: 11, wday: 6 }, { year: 2004, wnum1: 11 }, { hour: 23, min: 55 }, { year: 2004 },
 { cwyear: 2004 }, { seconds: -1 }, { seconds: Rational(-999, 1000), offset: 3600 }].each do |h|
  [Date, DateTime].each do |k|
    $counts[:complete_frags] += 1
    q1 = MereDateStrptime.new_by_frags(k, h, Date::ITALY, today.jd)
    fmt = +""
    str = +""
    h.each do |key, v|
      fmt << DIR_OF[key] << " "
      str << (key == :seconds ? (v * 1000).to_i.to_s : key == :offset ? format("%+05d", v / 36) : v.to_s) << " "
    end
    ref = begin ruby_quad(k.strptime(str, fmt)) rescue nil end
    $mismatches[:complete_frags] << [k, h, ref, q1] unless ref == q1
  end
end

# ------------------------------------------------------------ report

pairs = uniq.select { |kind, _, _| kind == :parse }.map { |_, _, a| a }.uniq
puts "ruby test file ran: #{test_ok ? 'all passed' : 'FAILED'} (#{recs.size} recorded calls, " \
     "#{pairs.size} distinct _strptime arg lists, #{uniq.count { |kind, _, _| kind == :new }} distinct strptime arg lists)"
puts test_log.lines.last(3).join unless test_ok
total = 0
bad = 0
$counts.keys.sort.each do |g|
  m = $mismatches[g].size
  total += $counts[g]
  bad += m
  printf "%-26s %6d checked  %4d mismatches   ruby gave %s\n", g, $counts[g], m, $kinds[g].sort.to_h.inspect
end
printf "%-26s %6d checked  %4d mismatches\n", "TOTAL", total, bad
$mismatches.each do |g, list|
  list.first(15).each { |x| puts "#{g}: #{x.inspect}" }
end
exit(bad.zero? ? 0 : 1)
