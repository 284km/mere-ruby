# Compares MereDateParse with CRuby's Date._x on
#  (1) every call the CRuby test file test/date/test_date_parse.rb makes to
#      Date._parse/_iso8601/... (recorded by running the test bodies with a
#      stub test/unit), plus every string literal in that file fed to every
#      reader (and to _parse with comp true and false);
#  (2) a generated corpus of extra inputs.
# Run with the reference interpreter:
#   ruby check_parse.rb [-v]
require "date"
require "ripper"
require_relative "../../lib/date_parse_ext"

TEST_FILE = "/Users/284km/src/github.com/ruby/ruby-4.0.9/test/date/test_date_parse.rb"
METHODS = %i[_parse _iso8601 _rfc3339 _xmlschema _rfc2822 _rfc822 _httpdate _jisx0301].freeze
VERBOSE = ARGV.include?("-v")

# ---------------------------------------------------------------- (1a)
# record the real calls of the test file
RECORDED = []
module DateParseRecorder
  METHODS.each do |m|
    define_method(m) do |*args, **kw, &blk|
      RECORDED << [m, args.map { |a| a.is_a?(String) ? a.dup : a }, kw] unless Thread.current[:dp_inner]
      Thread.current[:dp_inner] = true
      begin
        super(*args, **kw, &blk)
      ensure
        Thread.current[:dp_inner] = false
      end
    end
  end
end
Date.singleton_class.prepend(DateParseRecorder)

module Test
  module Unit
    class TestCase
      def assert_equal(*) = nil
      def assert_not_equal(*) = nil
      def assert_instance_of(*) = nil
      def assert_not_include(*) = nil
      def assert(*) = nil
      def assert_nothing_raised(*) = yield
      def assert_raise(*)
        yield
      rescue Exception
        nil
      end
      def all_assertions_foreach(_msg, *list)
        list.each { |x| yield x }
      end
    end
  end
end
module EnvUtil
  def self.timeout(_s) = yield
end

src = File.read(TEST_FILE)
src = src.lines.reject { |l| l =~ /\A\s*require\s+.(test\/unit|envutil)/ }.join
eval(src, TOPLEVEL_BINDING, TEST_FILE)
tc = TestDateParse
tc.instance_methods(false).grep(/\Atest/).sort.each do |name|
  begin
    tc.new.__send__(name)
  rescue Exception => e
    warn "test body #{name} raised #{e.class}: #{e.message[0, 100]}"
  end
end
Date.singleton_class.class_eval do
  METHODS.each { |m| DateParseRecorder.send(:remove_method, m) }
end

# ---------------------------------------------------------------- (1b)
# every string literal in the file
LITERALS = []
# each string token, evaluated (literals with interpolation are skipped)
def literal_strings(src)
  res = []
  toks = Ripper.lex(src)
  i = 0
  while i < toks.size
    (_, _), ev, tok = toks[i]
    if ev == :on_tstring_beg
      j = i + 1
      buf = +tok
      ok = true
      while j < toks.size
        (_, _), ev2, tok2 = toks[j]
        buf << tok2
        break if ev2 == :on_tstring_end
        ok = false if ev2 == :on_embexpr_beg
        j += 1
      end
      if ok
        begin
          v = eval(buf)
          res << v if v.is_a?(String)
        rescue Exception
        end
      end
      i = j + 1
    else
      i += 1
    end
  end
  res
end
LITERALS.concat(literal_strings(File.read(TEST_FILE)).uniq)

# ---------------------------------------------------------------- compare
def deep_same(a, b)
  return false unless a.class == b.class
  case a
  when Hash
    a.keys == b.keys && a.all? { |k, v| deep_same(v, b[k]) }
  when String
    a == b && a.encoding == b.encoding
  when Array
    a.size == b.size && a.zip(b).all? { |x, y| deep_same(x, y) }
  else
    a == b
  end
end

def call(target, m, args, kw)
  args = args.map { |a| a.is_a?(String) ? a.dup : a }
  target.__send__(m, *args, **kw)
rescue Exception => e
  [:raise, e.class, e.message]
end

$checked = 0
$mismatches = Hash.new { |h, k| h[k] = [] }
$seen = {}
def check(group, m, args, kw = {})
  key = [m, args, kw].inspect + args.map { |a| a.is_a?(String) ? a.encoding.to_s : "" }.join
  return if $seen[[group, key]]
  $seen[[group, key]] = true
  $checked += 1
  exp = call(Date, m, args, kw)
  got = call(MereDateParse, m, args, kw)
  same = deep_same(exp, got)
  # an exception: the class must agree (messages are reported, not required)
  if !same && exp.is_a?(Array) && got.is_a?(Array) && exp[0] == :raise && got[0] == :raise
    same = exp[1] == got[1]
  end
  $mismatches[group] << [m, args, kw, exp, got] unless same
  if ENV["DUMP"] && !(exp.is_a?(Array)) && args[0].is_a?(String) && args[0].encoding == Encoding::UTF_8 && args[0].valid_encoding? && (args.size == 1 || (args.size == 2 && args[1] == false))
    ($dump ||= []) << [m, args, kw, exp] unless exp.is_a?(Array)
  end
end

# (1)
RECORDED.each { |m, args, kw| check(:test_calls, m, args, kw) }
LITERALS.each do |s|
  METHODS.each { |m| check(:test_literals, m, [s]) }
  check(:test_literals, :_parse, [s, false])
end

# ---------------------------------------------------------------- (2)
def gen_inputs
  r = Random.new(20261107)
  out = []
  mons = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
  fmons = %w[January February March April May June July August September October November December]
  days = %w[Sun Mon Tue Wed Thu Fri Sat]
  fdays = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  zones = ["UTC", "GMT", "Z", "z", "JST", "EST", "EDT", "PST", "CET", "CEST", "MET DST", "BST",
           "+09:00", "-05:00", "+0900", "-0530", "+09", "-9", "+5:30", "+05:30:45", "-12:00:00",
           "+9.5", "-3,25", "+1.123456789", "GMT+9", "UTC-03:30", "GMT-090102", "AEST", "NZDT",
           "Eastern Standard Time", "Pacific Daylight Time", "Central Europe Standard Time",
           "E. Australia Standard Time", "W. Europe Standard Time", "Mid-Atlantic Standard Time",
           "Cen. Australia Standard Time", "IST", "a", "M", "Y", "UT", "XYZ", "+25:00", "+23:60",
           "+00:00:60", "-24", "+123456", "+1234567", "utc+1", "gmt-", "+ 9", "+0.5", "-0.25",
           "+12.75", "+05.", "+5:", "nzst dst", "JST  DST", "cest standard time", "Hawaiian Standard Time"]
  # years, months, days with variety
  200.times do
    y = [r.rand(1..2100), r.rand(0..99), r.rand(1000..9999), -r.rand(1..3000), r.rand(10000..99999)].sample(random: r)
    m = r.rand(1..12)
    d = r.rand(1..31)
    hh = r.rand(0..23); mi = r.rand(0..59); ss = r.rand(0..60)
    z = zones.sample(random: r)
    f = (1..9).to_a.sample(random: r).then { |n| Array.new(n) { r.rand(0..9) }.join }
    ys = y.to_s
    y2 = format("%02d", y.abs % 100)
    case r.rand(30)
    when 0 then out << format("%s-%02d-%02d", ys, m, d)
    when 1 then out << format("%s-%02d-%02dT%02d:%02d:%02d%s", ys, m, d, hh, mi, ss, z)
    when 2 then out << format("%s-%02d-%02d %02d:%02d:%02d.%s %s", ys, m, d, hh, mi, ss, f, z)
    when 3 then out << format("%s, %d %s %s %02d:%02d:%02d %s", days.sample(random: r), d, mons[m - 1], ys, hh, mi, ss, z)
    when 4 then out << format("%s %s %2d %02d:%02d:%02d %s %s", days.sample(random: r), mons[m - 1], d, hh, mi, ss, z, ys)
    when 5 then out << format("%d/%d/%s", m, d, ys)
    when 6 then out << format("%s/%d/%d", ys, m, d)
    when 7 then out << format("%d.%d.%s", d, m, ys)
    when 8 then out << format("%s %d, %s", fmons[m - 1], d, ys)
    when 9 then out << format("%d %s %s", d, fmons[m - 1], ys)
    when 10 then out << format("%dth %s %s BC", d, mons[m - 1], ys)
    when 11 then out << format("%s %d %s B.C.", mons[m - 1], d, ys)
    when 12 then out << format("%s %s %d", ys, mons[m - 1], d)
    when 13 then out << format("%d-%s-%s", d, mons[m - 1], ys)
    when 14 then out << format("%s-%d-%s", mons[m - 1], d, ys)
    when 15 then out << format("%s%02d%02d", ys, m, d)
    when 16 then out << format("%s%02d%02dT%02d%02d%02d%s", ys, m, d, hh, mi, ss, z)
    when 17 then out << format("%s%02d%02d%02d%02d%02d", ys, m, d, hh, mi, ss)
    when 18 then out << format("%s-w%02d-%d", ys, r.rand(1..53), r.rand(1..7))
    when 19 then out << format("%sw%02d%d", ys, r.rand(1..53), r.rand(1..7))
    when 20 then out << format("%s-%03d", ys, r.rand(1..366))
    when 21 then out << format("%s%03d", ys, r.rand(1..366))
    when 22 then out << format("%s%02d.%02d.%02d", %w[M T S H R m h r].sample(random: r), r.rand(1..64), m, d)
    when 23 then out << format("%s%02d.%02d.%02dT%02d:%02d:%02d%s", %w[M T S H R].sample(random: r), r.rand(1..64), m, d, hh, mi, ss, ["", "Z", "+09:00", "+0900", ",5"].sample(random: r))
    when 24 then out << format("%02d:%02d:%02d %s", hh, mi, ss, z)
    when 25 then out << format("%d:%02d %s", r.rand(1..12), mi, %w[am pm AM PM a.m. p.m.].sample(random: r))
    when 26 then out << format("%s, %02d-%s-%s %02d:%02d:%02d GMT", fdays.sample(random: r), d, mons[m - 1], y2, hh, mi, ss)
    when 27 then out << format("%s, %02d %s %s %02d:%02d:%02d GMT", days.sample(random: r), d, mons[m - 1], ys, hh, mi, ss)
    when 28 then out << format("'%s %s %d", y2, mons[m - 1], d)
    when 29 then out << format("%s %02d:%02d:%02d%s", [format("%02d%02d", m, d), format("%s%02d%02d", y2, m, d)].sample(random: r), hh, mi, ss, ["", "Z", "+0900", "[+9]", "[-5:EST]", "[9:JST]", "[+09:30]"].sample(random: r))
    end
  end
  # time-only and zone corpus
  zones.each do |z|
    out << "10:20:30 #{z}"
    out << "2001-02-03T04:05:06#{z}"
    out << "Sat Aug 28 02:29:34 #{z} 1999"
    out << "2001-02-03 04:05:06 #{z}"
  end
  # hand-picked
  out.concat [
    "", " ", "garbage", "foo bar baz", "123", "1", "12", "1234", "12345", "123456", "1234567", "12345678",
    "123456789", "1234567890", "12345678901", "123456789012", "1234567890123", "12345678901234",
    "123456789012345", "-123456", "+20010203", "20010203T", "20010203T04", "20010203T0405",
    "20010203T040506", "20010203T040506.123", "040506.5", "0405.5", "05.25", "t040506", "20010203 040506Z",
    "20010203 0405+9", "010203 040506 -0530", "20010203[+9:JST]", "20010203[-5]", "20010203[EST]",
    "Jan", "January 2001", "jan 1st", "1st", "2nd", "23rd", "31st Dec", "the 4th of July 1776",
    "Christmas 2001", "July 4", "4 July", "Jul-4", "Jul-4-1776", "4-Jul-1776", "4-jul-76",
    "Tue", "tuesday", "next tuesday", "Wed 10am", "noon", "12 noon", "12pm", "12am", "0am", "13pm",
    "10h", "10h30", "10h30m", "10h30m45s", "10 h 30 m 45 s", "10:30:45,123", "10:30:45.", "10 : 30 : 45",
    "3 p.m.", "3 a.m. JST", "3pm EST", "3pm Pacific Standard Time", "15:00 Tokyo Standard Time",
    "2001-02-03 BC", "2001-02-03 bce", "3 Feb 2001 b.c.", "3 Feb 2001 b.c.e.", "Feb 3 2001 AD", "Feb 3 2001 C.E.",
    "3 Feb 50 AD", "3 Feb -50", "Feb 3, -50", "-0001-01-01", "+2001-01-01", "'01-02-03", "01-02-'03",
    "2001-W05", "2001W05", "W05", "-W05-3", "-W-3", "--02-03", "--0203", "--02", "---03", "2001-034", "-034",
    "01.02.2003", "1.2.3", "2003.01.02", "H13.02.03", "h13.2.3", "R1.5.1", "x13.02.03", "S64.01.07",
    "2001/02/03", "02/03/2001", "2/3", "2001/2", "'99/2/3", "2/3/'99", "1/2/3/4", "2001/02/03 04:05:06",
    "Sat, 03 Feb 2001 04:05:06 GMT", "Saturday, 03-Feb-01 04:05:06 GMT", "Sat Feb  3 04:05:06 2001",
    "Sat, 3 Feb 2001 04:05 +0900", "3 Feb 2001 04:05:06 +0900", "Sat, 03 Feb 01 04:05:06 EST",
    "Sat, 03 Feb 001 04:05:06 Z", "Sat, 03 Feb 2001 04:05:06 J", "Sat, 03 Feb 2001 04:05:06 PDT",
    "Monday, 01-Jan-70 00:00:00 GMT", "Sunday, 01-Jan-69 00:00:00 GMT", "Sun, 01-Jan-1970 00:00:00 GMT",
    "2001-02-03T04:05:06.123456789+09:00", "2001-02-03 04:05:06-00:00", "-2001-02-03T04:05:06Z",
    "2001-02-03t04:05:06z", "92001-02-03", "-92001-02-03T04:05:06Z", "2001-02", "2001", "--02-03Z",
    "---03+09:00", "04:05:06.5-01:00", "04:05", "0405", "040506", "040506Z", "040506+09", "040506+0930",
    "04:05:06+09", "04:05:06+0930", "04:05:06+09:30", "01-02-03", "01-023", "1-02-03", "001-02-03",
    "2001-02-03T04", "2001-02-03T04:05Z", "2001-02-03T04:05:06,5", "2001-W05-3T04:05:06Z", "2001W053T040506",
    "\t2001-02-03\n", "2001-02-03 　", "２００１年２月３日", "2001年2月3日", "Feb 3", "Ḟeb 3",
    "Jan 1 0", "Jan - 1", "Jan 00001", "Jan 1, 00001", "1 Jan 00001", "Sat Aug 28 02:55:50 +09",
    "12:00 +09:00:60", "12:00 +24:00", "12:00 GMT+25", "12:00 GMT+9.5", "12:00 GMT-9.25",
    "12:00 +1.0000001", "12:00 +1.00000005", "12:00 +1.00000015", "12:00 +1.000000049",
    "12:00 -00.5", "12:00 +09:0", "12:00 +9:00:00:00", "12:00 utc", "12:00 Utc+3", "12:00 gmt +3",
    "12:00 EST5EDT", "12:00 E. Europe Standard Time", "12:00 e.  europe   standard   time",
    "12:00 Mountain Daylight Time", "12:00 Atlantic Daylight Time", "12:00 x dst",
    "10:00 Australian Eastern Standard Time", "1:00 Arabian Standard Time",
    "5 Jan 2001 10:00 CST", "Jan 5 01:02:03.04 2001 -0500", "2001 Jan 5", "2001Jan5", "5Jan2001", "Jan5",
    "1999-05-23\t\n\v\f\r 21:34:56", "21:34:56 1999-05-23", "23 05 1999", "1999 05 23",
    "abc 2001-02-03 xyz", "2001-02-03-04", "2001--02-03", "2001-02--03", "-2001-02-03", "+-2001-02-03",
    "1/1/1/1", "10/20", "10/2001", "13/13/13", "0/0/0", "1 . 2 . 3", "1. 2. 3", "'1.'2.'3",
    "2001.034", "2001,034", "x-034", "1-034", "a 2001-034", ".01-034",
    "Mon Tue Wed", "Jan Feb 3", "3 Jan Feb", "january february", "sat sun 2001-02-03",
    "12/31/1999 11:59:59 PM", "12/31/1999 11:59:59.999 PM EST", "31/12/1999 23:59", "1999-12-31 23:59:60",
    "24:00", "25:00", "23:59:61", "99:99:99", "123:45", "1:2:3", "01:02:03:04", "1:2", "T10:20",
    "1 2 3", "1", "31", "32", "0", "00", "2000-01-02 0", "2000-01-02 25", "1 03:04", "32 03:04",
    "2001-02-03 4", "Feb 3 4", "Feb 3 4:05", "4 PM Feb 3", "5 o'clock", "o'clock", "'", "''", "'99", "'1999",
    "BC", "bc 2001", "2001 b.c", "1 BCE", "Jan 1 1 BC", "1 Jan 1 bce", "-1-1-1",
    "w12", "2001w12", "01w12-3", "2001-w12-3", "1w12", "2001-w1", "2001-w123", "-w-8", "-w-9x",
    "1999-123T10:20:30", "1999123T102030", "99123", "+99123", "-99123", "+1999123",
    "\x00\x01 2001-02-03", "2001-02-03\x7f", "date: 2001-02-03; time: 04:05", "@2001-02-03",
    "[2001-02-03]", "(2001-02-03)", "2001-02-03 [+9]", "20010203 [+9:JST]",
    "20010203 [+09:00:JST:x]", "20010203 [-0]", "20010203 [+9:]", "20010203 []", "20010203 [0x]",
    "20010203Z", "20010203 Z", "20010203 z", "20010203 +0900", "20010203 +9", "20010203 +12345",
    "20010203 t", "20010203t0405", "2001020304", "200102030405", "20010203040506", "2001020304050",
    "1200am", "1200pm", "120000pm", "1200 pm", "10 h pm", "10h 30m pm",
  ]
  # token soup and mutations of the inputs above
  toks = %w[2001 01 1 12 31 99 0099 -2001 +09:00 -0530 +9 Z T t W w - -- / . , : ' ' ' ' ' ' Jan feb MAR
            September Sat sunday BC b.c. AD c.e. am pm a.m. P.M. JST EST GMT UTC dst standard time daylight
            Eastern Pacific H13 R01 S64 [+9:JST] [-5] th st nd rd 123 4567 040506 20010203 .5 ,25 h m s x @ \t]
  1500.times do
    n = r.rand(1..7)
    out << Array.new(n) { toks.sample(random: r) }.join([" ", "", ""].sample(random: r))
  end
  base = out.dup
  1500.times do
    s = base.sample(random: r).dup
    next if s.empty?
    r.rand(1..3).times do
      i = r.rand(0...[s.size, 1].max)
      case r.rand(3)
      when 0 then s[i] = ""
      when 1 then s.insert(i, "0123456789-/.:, +TZtWwABab'"[r.rand(27)])
      else s[i] = "0123456789-/.:, +T"[r.rand(18)]
      end
    end
    out << s
  end
  out
end

EXTRA = gen_inputs.uniq
EXTRA.each do |s|
  METHODS.each { |m| check(:extra, m, [s]) }
  check(:extra, :_parse, [s, false])
end
# non-String / limit behaviour
[nil, 1, :sym, "1" * 129, "1" * 1000].each do |s|
  METHODS.each { |m| check(:extra, m, [s]) }
end
check(:extra, :_parse, ["1" * 1000], limit: nil)
check(:extra, :_parse, ["1" * 1000], limit: 1000)
check(:extra, :_parse, ["1" * 1000], limit: 999)
check(:extra, :_iso8601, ["2001-02-03"], limit: 5)
check(:extra, :_parse, ["Jan " + "9" * 2000], limit: 3000)
check(:extra, :_parse, ["2001-02-03".encode("UTF-16LE")])
check(:extra, :_parse, ["2001-02-03 JST".encode("EUC-JP")])
check(:extra, :_parse, ["2001-02-03 JST".b])

# ---------------------------------------------------------------- report
total_mm = 0
puts "test calls recorded: #{RECORDED.size}, string literals: #{LITERALS.size}, extra inputs: #{EXTRA.size}"
%i[test_calls test_literals extra].each do |g|
  n = $seen.keys.count { |k| k[0] == g }
  mm = $mismatches[g]
  total_mm += mm.size
  puts "#{g}: #{n} cases, #{mm.size} mismatches"
  mm.first(VERBOSE ? 10_000 : 40).each do |m, args, kw, exp, got|
    a = args.map { |x| x.is_a?(String) && x.size > 60 ? "#{x[0, 30].inspect}...(#{x.size})" : x.inspect }.join(", ")
    a += ", #{kw.inspect}" unless kw.empty?
    puts "  #{m}(#{a})"
    puts "    expected: #{exp.inspect[0, 300]}"
    puts "    got:      #{got.inspect[0, 300]}"
  end
end
puts "total: #{$checked} cases, #{total_mm} mismatches"
if ENV["DUMP"]
  File.open(ENV["DUMP"], "w") do |f|
    f.puts "CASES = ["
    $dump.each { |m, args, kw, exp| f.puts "  [#{m.inspect}, #{args.inspect}, #{kw.inspect}, #{exp.inspect.inspect}]," }
    f.puts "]"
  end
end
