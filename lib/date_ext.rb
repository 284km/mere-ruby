# frozen_string_literal: false
#
# Date and DateTime, as mere-ruby answers `require "date"` (and "date_core"):
# written here in Ruby over Integer and Rational, where ruby has
# ext/date (C). Shipped through tools/gen_pathname_lib.rb. It grew in
# layers -- each `class Date` below reopens the one before -- and the
# layers are kept as they were when the file left m_eval_leaf.mere.
class Date
  include Comparable

  # mere-ruby's Date is proleptic Gregorian only. CRuby's `start` argument
  # selects a calendar reform date; these constants exist so callers that
  # pass one (psych does) work, but they are all the same calendar here.
  ITALY = 2299161
  ENGLAND = 2361222
  GREGORIAN = -Float::INFINITY
  JULIAN = Float::INFINITY

  # frozen, tables and names alike, as ruby's are
  # (US-ASCII, as ruby's are: test_switch_hitter asks)
  ABBR_DAYNAMES = %w[Sun Mon Tue Wed Thu Fri Sat].map { |s| s.force_encoding(Encoding::US_ASCII).freeze }.freeze
  DAYNAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].map { |s| s.force_encoding(Encoding::US_ASCII).freeze }.freeze
  ABBR_MONTHNAMES = ([nil] + %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].map { |s| s.force_encoding(Encoding::US_ASCII).freeze }).freeze
  MONTHNAMES = ([nil] + %w[January February March April May June July August
                          September October November December].map { |s| s.force_encoding(Encoding::US_ASCII).freeze }).freeze

  # civil -> Julian Day Number (proleptic Gregorian)
  def self.civil_to_jd(y, m, d)
    a = (14 - m) / 12
    y2 = y + 4800 - a
    m2 = m + 12 * a - 3
    d + (153 * m2 + 2) / 5 + 365 * y2 + y2 / 4 - y2 / 100 + y2 / 400 - 32045
  end

  def self.jd_to_civil(jd)
    a = jd + 32044
    b = (4 * a + 3) / 146097
    c = a - 146097 * b / 4
    d2 = (4 * c + 3) / 1461
    e = c - 1461 * d2 / 4
    m2 = (5 * e + 2) / 153
    day = e - (153 * m2 + 2) / 5 + 1
    month = m2 + 3 - 12 * (m2 / 10)
    year = 100 * b + d2 - 4800 + m2 / 10
    [year, month, day]
  end

  def self.leap?(y)
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
  end

  def self.valid_civil?(y, m, d, _start = nil)
    return false if m < 1 || m > 12 || d < 1
    d <= days_in_month(y, m)
  end

  def self.days_in_month(y, m)
    return 29 if m == 2 && leap?(y)
    [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m]
  end

  def self.jd(n = 0, _start = nil)
    allocate.__set_jd(n)
  end

  def self.today(_start = nil)
    t = Time.now
    new(t.year, t.month, t.day)
  end

  # The fields a free-form date names, as ruby's Date._parse finds them:
  # an ISO date (and time), day and month names, ordinals (5th), numbers
  # with . / - or space between them (Y-M-D when the first has 3+ digits,
  # D-M-Y when the last has, else YY-MM-DD), and bare digit runs by length
  # (DD, DDD year day, MMDD, YYDDD, YYMMDD, YYYYDDD, YYYYMMDD). A two-digit
  # year is 1969-2068 when comp is true.
  def self.__limit(str, limit)
    return unless limit && str.is_a?(String) && str.size > limit
    raise ArgumentError, "string length (#{str.size}) exceeds the limit #{limit}"
  end
  def self._parse(str, comp = true, limit: 128)
    raise TypeError, "no implicit conversion of #{str.class} into String" unless str.respond_to?(:to_str)
    __limit(str.to_str, limit)
    t = str.to_str.downcase
    h = {}
    yy = lambda { |y, digits| comp && digits <= 2 ? (y >= 69 ? y + 1900 : y + 2000) : y }
    mons = %w[jan feb mar apr may jun jul aug sep oct nov dec]
    days = %w[sun mon tue wed thu fri sat]
    if (m = t.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/))
      h[:hour] = m[1].to_i
      h[:min] = m[2].to_i
      h[:sec] = m[3].to_i if m[3]
      t = t.sub(m[0], " ")
    end
    if (m = t.match(/\b(sun|mon|tue|wed|thu|fri|sat)[a-z]*/))
      h[:wday] = days.index(m[1])
      t = t.sub(m[0], " ")
    end
    mon_re = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*"
    if (m = t.match(/(-?\d{4})-(\d{1,2})-(\d{1,2})/))
      h[:year], h[:mon], h[:mday] = m[1].to_i, m[2].to_i, m[3].to_i
    elsif (m = t.match(/(-?\d{3,})[^a-z0-9]*#{mon_re}[^a-z0-9]*(\d+)/))
      h[:year], h[:mon], h[:mday] = m[1].to_i, mons.index(m[2]) + 1, m[3].to_i
    elsif (m = t.match(/(\d+)(?:st|nd|rd|th)?[^a-z0-9-]*#{mon_re}[^a-z0-9-]*(-?\d+)/))
      h[:mday], h[:mon], h[:year] = m[1].to_i, mons.index(m[2]) + 1, yy.call(m[3].to_i, m[3].delete("-").size)
    elsif (m = t.match(/#{mon_re}[^a-z0-9-]*(\d+)(st|nd|rd|th)[^a-z0-9-]*(-?\d+)/))
      h[:mon], h[:mday], h[:year] = mons.index(m[1]) + 1, m[2].to_i, yy.call(m[4].to_i, m[4].delete("-").size)
    elsif (m = t.match(/#{mon_re}[^a-z0-9-]*(\d+)(?:st|nd|rd|th)/))
      h[:mon], h[:mday] = mons.index(m[1]) + 1, m[2].to_i
    elsif (m = t.match(/#{mon_re}[^a-z0-9-]*(-?\d{3,})/))
      h[:mon], h[:year] = mons.index(m[1]) + 1, m[2].to_i
    elsif (m = t.match(/#{mon_re}/))
      h[:mon] = mons.index(m[1]) + 1
    elsif (m = t.match(/(-?\d+)[.\/ -](\d+)[.\/ -](-?\d+)/))
      a, b2, c = m[1], m[2], m[3]
      if a.delete("-").size >= 3
        h[:year], h[:mon], h[:mday] = a.to_i, b2.to_i, c.to_i
      elsif c.delete("-").size >= 3
        h[:mday], h[:mon], h[:year] = a.to_i, b2.to_i, c.to_i
      else
        h[:year], h[:mon], h[:mday] = yy.call(a.to_i, a.size), b2.to_i, c.to_i
      end
    elsif (m = t.match(/(\d+)(?:st|nd|rd|th)/))
      h[:mday] = m[1].to_i
    elsif (m = t.match(/\A\s*(\d+)\s*\z/))
      d = m[1]
      case d.size
      when 2 then h[:mday] = d.to_i
      when 3 then h[:yday] = d.to_i
      when 4 then h[:mon], h[:mday] = d[0, 2].to_i, d[2, 2].to_i
      when 5 then h[:year], h[:yday] = yy.call(d[0, 2].to_i, 2), d[2, 3].to_i
      when 6 then h[:year], h[:mon], h[:mday] = yy.call(d[0, 2].to_i, 2), d[2, 2].to_i, d[4, 2].to_i
      when 7 then h[:year], h[:yday] = d[0, 4].to_i, d[4, 3].to_i
      when 8 then h[:year], h[:mon], h[:mday] = d[0, 4].to_i, d[4, 2].to_i, d[6, 2].to_i
      end
    end
    h
  end

  # the civil fields of a _parse hash, the missing ones taken from today
  def self.__parsed_civil(h)
    today = Date.today
    if h[:yday]
      y = h[:year] || today.year
      j = civil_to_jd(y, 1, 1) + h[:yday] - 1
      return jd_to_civil(j)
    end
    if h[:wday] && !h[:mday] && !h[:mon]
      w = h[:wday] == 0 ? 7 : h[:wday]
      return jd_to_civil(commercial_to_jd(today.cwyear, today.cweek, w))
    end
    [h[:year] || today.year, h[:mon] || (h[:mday] ? today.month : 1), h[:mday] || 1]
  end

  def self.parse(str = "-4712-01-01", comp = true, _start = nil, limit: 128)
    h = _parse(str, comp, limit: limit)
    raise Date::Error, "invalid date" if h.empty? || !(h.key?(:year) || h.key?(:mon) || h.key?(:mday) || h.key?(:yday) || h.key?(:wday))
    y, m, d = __parsed_civil(h)
    raise Date::Error, "invalid date" unless valid_civil?(y, m, d)
    new(y, m, d)
  end
  # The fields `fmt` names in `str`, as ruby's Date._strptime reports them,
  # or nil when the text does not follow the format. Composite directives
  # (%c %D %F %v %+ ...) are spelled out first; a space in the format
  # matches any run of white space.
  def self._strptime(str, fmt = "%F")
    comp = { "c" => "%a %b %e %H:%M:%S %Y", "D" => "%m/%d/%y", "x" => "%m/%d/%y",
             "F" => "%Y-%m-%d", "v" => "%e-%b-%Y", "+" => "%a %b %e %H:%M:%S %Z %Y",
             "T" => "%H:%M:%S", "X" => "%H:%M:%S", "R" => "%H:%M", "r" => "%I:%M:%S %p", "h" => "%b" }
    f = fmt
    4.times { f = f.gsub(/%([cDxFv+TXRrh])/) { comp[$1] } }
    mons = %w[jan feb mar apr may jun jul aug sep oct nov dec]
    days = %w[sun mon tue wed thu fri sat]
    h = {}
    s = str
    pos = 0
    i = 0
    num = lambda do |width, signed|
      m = s[pos..].match(signed ? /\A[-+]?\d{1,#{width}}/ : /\A\d{1,#{width}}/)
      return nil unless m
      pos += m[0].size
      m[0].to_i
    end
    while i < f.size
      c = f[i]
      if c == "%" && i + 1 < f.size
        d = f[i + 1]
        i += 2
        v = nil
        case d
        when "Y" then v = num.call(20, true); h[:year] = v
        when "y" then v = num.call(2, false); h[:year] = v && (v >= 69 ? v + 1900 : v + 2000); h[:_y2] = v
        when "C" then v = num.call(2, true); h[:_cent] = v
        when "m" then v = num.call(2, false); h[:mon] = v
        when "d", "e"
          pos += 1 if s[pos] == " "
          v = num.call(2, false); h[:mday] = v
        when "j" then v = num.call(3, false); h[:yday] = v
        when "H", "k", "I", "l"
          pos += 1 if s[pos] == " "
          v = num.call(2, false); h[:hour] = v
        when "M" then v = num.call(2, false); h[:min] = v
        when "S" then v = num.call(2, false); h[:sec] = v
        when "U" then v = num.call(2, false); h[:wnum0] = v
        when "W" then v = num.call(2, false); h[:wnum1] = v
        when "u" then v = num.call(1, false); h[:cwday] = v
        when "w" then v = num.call(1, false); h[:wday] = v
        when "G" then v = num.call(20, true); h[:cwyear] = v
        when "g" then v = num.call(2, false); h[:cwyear] = v && (v >= 69 ? v + 1900 : v + 2000)
        when "V" then v = num.call(2, false); h[:cweek] = v
        when "a", "A", "b", "B"
          m = s[pos..].match(/\A[a-zA-Z]+/)
          if m
            w = m[0].downcase
            list = (d == "a" || d == "A") ? days : mons
            k = list.index(w[0, 3])
            full = (d == "a" || d == "A") ? %w[sunday monday tuesday wednesday thursday friday saturday] : %w[january february march april may june july august september october november december]
            if k && (w.size == 3 || full[k] == w)
              pos += w.size
              v = k
              if d == "a" || d == "A" then h[:wday] = k else h[:mon] = k + 1 end
            end
          end
        when "p", "P"
          m = s[pos..].match(/\A[aApP]\.?[mM]\.?/)
          if m
            pos += m[0].size
            v = m[0]
            h[:_merid] = m[0].downcase.start_with?("p") ? 12 : 0
          end
        when "Z", "z"
          m = s[pos..].match(/\A(?:[-+]\d{1,2}(?::?\d{2})?|[a-zA-Z]+)/)
          if m
            pos += m[0].size
            v = h[:zone] = m[0]
            if (zm = v.match(/\A([-+])(\d{1,2}):?(\d{2})?\z/))
              h[:offset] = (zm[1] == "-" ? -1 : 1) * (zm[2].to_i * 3600 + zm[3].to_i * 60)
            elsif %w[utc gmt z].include?(v.downcase)
              h[:offset] = 0
            end
          end
        when "%"
          v = s[pos] == "%" ? (pos += 1) : nil
        else
          return nil
        end
        return nil if v.nil?
      elsif c =~ /\s/
        i += 1
        pos += 1 while pos < s.size && s[pos] =~ /\s/
      else
        return nil unless s[pos] == c
        pos += 1
        i += 1
      end
    end
    if h.key?(:_cent)
      c = h.delete(:_cent)
      y2 = h.delete(:_y2)
      h[:year] = c * 100 + (y2 || (h[:year] || 0) % 100)
    end
    h.delete(:_y2)
    if h.key?(:_merid)
      mer = h.delete(:_merid)
      h[:hour] = h[:hour] % 12 + mer if h[:hour]
    end
    h[:leftover] = s[pos..] if pos < s.size
    h
  end

  # the day _strptime's fields name, the missing ones taken from today the way
  # ruby completes them: a year day, then a month and day, then the commercial
  # fields, then a week number, then a bare week day.
  def self.__strptime_jd(h)
    today = Date.today
    if h[:yday]
      return civil_to_jd(h[:year] || today.year, 1, 1) + h[:yday] - 1
    end
    if h[:mon] || h[:mday]
      y = h[:year] || today.year
      m = h[:mon] || (h[:mday] ? today.month : 1)
      d = h[:mday] || 1
      return nil unless valid_civil?(y, m, d)
      return civil_to_jd(y, m, d)
    end
    if h[:cweek] || h[:cwyear] || h[:cwday]
      return commercial_to_jd(h[:cwyear] || today.cwyear, h[:cweek] || 1, h[:cwday] || 1)
    end
    y = h[:year] || today.year
    jd1 = civil_to_jd(y, 1, 1)
    wd1 = (jd1 + 1) % 7
    return jd1 - wd1 + 7 * h[:wnum0] + (h[:wday] || 0) if h[:wnum0]
    return jd1 - (wd1 + 6) % 7 + 7 * h[:wnum1] + ((h[:wday] || 1) + 6) % 7 if h[:wnum1]
    if h[:wday]
      return jd1 - wd1 + h[:wday] if h[:year]
      return today.jd - today.wday + h[:wday]
    end
    civil_to_jd(y, 1, 1)
  end

  def self.strptime(str = "-4712-01-01", fmt = "%F", _start = nil)
    h = _strptime(str, fmt)
    raise Date::Error, "invalid date" if h.nil?
    jd = __strptime_jd(h)
    raise Date::Error, "invalid date" if jd.nil?
    Date.jd(jd)
  end

  def self.new(y = -4712, m = 1, d = 1, _start = nil)
    obj = allocate
    if d < 0
      d = days_in_month(y, m) + d + 1
    end
    raise Date::Error, "invalid date" unless valid_civil?(y, m, d)
    obj.__set_jd(civil_to_jd(y, m, d))
  end

  class Error < ArgumentError; end

  def __set_jd(n)
    @jd = n
    y, m, d = Date.jd_to_civil(n)
    @year = y
    @month = m
    @day = d
    self
  end

  attr_reader :jd, :year, :month, :day

  alias mon month
  alias mday day

  def wday = (@jd + 1) % 7
  def sunday? = wday == 0
  def monday? = wday == 1
  def tuesday? = wday == 2
  def wednesday? = wday == 3
  def thursday? = wday == 4
  def friday? = wday == 5
  def saturday? = wday == 6

  def yday = @jd - Date.civil_to_jd(@year, 1, 1) + 1
  def leap? = Date.leap?(@year)

  def +(n) = Date.jd(@jd + n.to_i)
  def -(other)
    return Date.jd(@jd - other) if other.is_a?(Integer)
    Rational(@jd - other.jd, 1)
  end

  def next_day(n = 1) = Date.jd(@jd + n)
  def prev_day(n = 1) = Date.jd(@jd - n)
  def succ = next_day
  alias next succ

  # >> and << move by months, clamping the day to the target month's length
  def >>(n)
    total = (@year * 12 + (@month - 1)) + n
    y = total / 12
    m = total % 12 + 1
    d = @day
    last = Date.days_in_month(y, m)
    d = last if d > last
    Date.new(y, m, d)
  end

  def <<(n)
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    self >> (-n)
  end
  def next_month(n = 1) = self >> n
  def prev_month(n = 1) = self << n
  def next_year(n = 1) = self >> (12 * n)
  def prev_year(n = 1) = self << (12 * n)

  def <=>(other)
    return @jd <=> other.jd if other.is_a?(Date)
    return @jd <=> other if other.is_a?(Numeric)
    nil
  end

  def ==(other) = other.is_a?(Date) && @jd == other.jd
  def eql?(other) = self == other
  def hash = @jd.hash

  def to_date = self
  # (a negative year keeps four digits after its sign: -0001-12-31)
  def to_s = format("%s%04d-%02d-%02d", @year < 0 ? "-" : "", @year.abs, @month, @day).force_encoding(Encoding::US_ASCII)
  def iso8601 = to_s
  # the day number, the day fraction, the offset and the calendar reform,
  # as ruby shows them (a proleptic calendar's reform is -Inf / Inf)
  def inspect
    st = start
    sts = st.infinite? ? (st < 0 ? "-Inf" : "Inf") : st.to_i.to_s
    "#<Date: #{self} ((#{jd}j,0s,0n),+0s,#{sts}j)>".force_encoding(Encoding::US_ASCII)
  end

  def to_time = Time.local(@year, @month, @day)

  # the one strftime engine (Time.__strf), with a Date's fields: midnight,
  # at offset zero, and %Q allowed
  def strftime(fmt = "%F")
    Date.__strf_range_check(fmt, @year)
    r = Time.__strf(fmt, [@year, @month, @day, yday, wday, 0, 0, 0, 0, 0, false, "+00:00", (jd - 2440588) * 86400, true])
    r.ascii_only? ? r.force_encoding(Encoding::US_ASCII) : r
  end
  # (a width of 8192 or more, or a year of more than 2048 digits, is
  #  ruby's Errno::ERANGE -- its buffer, not a date)
  def self.__strf_range_check(fmt, y)
    raise Errno::ERANGE if y.abs.to_s.size > 2048 && fmt.include?("%")
    fmt.scan(/%[-_0^#:]*(\d+)/) { |(w)| raise Errno::ERANGE if w.to_i >= 8192 }
    nil
  end
end

class DateTime < Date
  # ⚠ THIS BUILT A DATE. `Date.new(y, m, d)` allocates the class it is CALLED
  #   on, and calling it by name means Date -- so `DateTime.new(...).class`
  #   was Date, `DateTime.instance_methods(false)` was empty, and every
  #   DateTime-specific method was reached by inheritance from an object
  #   that is not a DateTime. #iso8601 answered "2020-01-02" for that
  #   reason. `super` runs the same code with self still DateTime.
  # ⚠ THE SEVENTH ARGUMENT IS THE OFFSET, a fraction of a day, and it was
  # dropped: every DateTime claimed +00:00. ruby takes a Rational, an
  # Integer, a Float (rationalized -- 0.7 is 7/10, not the binary fraction)
  # or "+HH:MM"; the civil fields are read AS local to that offset, so only
  # #offset, #zone and the printers change.
  def self.new(y = -4712, m = 1, d = 1, h = 0, min = 0, s = 0, off = 0, _start = nil)
    obj = super(y, m, d, _start)
    obj.__set_time(h, min, s)
    obj.__set_offset(Date.__offset_of(off))
    obj
  end

  # a DateTime prints the whole timestamp; Date's #to_s is the date alone.
  def to_s
    (format("%s%04d-%02d-%02dT%02d:%02d:%02d", year < 0 ? "-" : "", year.abs, month, day, hour, minute, second) + __off_s).force_encoding(Encoding::US_ASCII)
  end
  def inspect = "#<DateTime: #{self}>".force_encoding(Encoding::US_ASCII)

  # ⚠ with the fraction and the OFFSET: this read the local wall clock and
  # built it at +00:00, so `DateTime.now.to_time` was the local offset away
  # from Time.now (nine hours, on the machine that found it)
  def self.now(_start = Date::ITALY)
    t = Time.now
    new(t.year, t.month, t.day, t.hour, t.min, t.sec + t.subsec, Rational(t.utc_offset, 86400))
  end
end

class Date
  # (a Date has no time of day; its printers read midnight at +00:00
  #  through these, and DateTime answers its own)
  def __hour = 0
  def __minute = 0
  def __second = 0
  def __offset = Rational(0, 1)
  def self.__offset_of(off) = DateTime.__offset_of(off)
end
class DateTime < Date
  def __hour = hour
  def __minute = minute
  def __second = second
  def __offset = offset
  def __set_time(h, mi, s)
    @hour = h
    @minute = mi
    @second = s
    self
  end

  def hour = @hour || 0
  # ⚠ THESE ARE ALIASES, not two methods that answer the same value. The
  #   specs compare the UnboundMethods -- `DateTime.instance_method(:min)
  #   == DateTime.instance_method(:minute)` -- and `def min = minute`
  #   defines a SECOND method that forwards, which is not equal to the
  #   first. alias_method makes them one.
  def minute = @minute || 0
  alias_method :min, :minute
  def second = @second || 0
  alias_method :sec, :second
  # the sub-second part, as a Rational. This model keeps whole seconds, so
  # it is always zero -- said as a Rational because that is the TYPE the
  # caller gets from ruby, and an Integer 0 would compare the same and
  # print differently.
  def sec_fraction = Rational(0, 1)
  alias_method :second_fraction, :sec_fraction
  def offset = @offset || Rational(0, 1)
  def __set_offset(o)
    @offset = o
    self
  end
  def self.__offset_of(off)
    case off
    when String
      m = /\A([+-])(\d{2}):?(\d{2})\z/.match(off)
      return Rational(0, 1) unless m
      r = Rational(m[2].to_i * 3600 + m[3].to_i * 60, 86400)
      m[1] == "-" ? -r : r
    when Float then off.rationalize(Rational(1, 864000000))
    when Integer, Rational then Rational(off)
    else Rational(0, 1)
    end
  end
  def zone = __off_s
  # ⚠ DateTime#iso8601 answered the DATE only -- Date#iso8601, inherited --
  #   so a DateTime printed as "2020-01-02" where ruby gives the full
  #   timestamp. It is #to_s here, as it is for Date.
  def iso8601 = to_s
end
class Date
  # `new` is the shim's constructor; `civil` is the SAME constructor under the
  # name ruby/spec writes 23 of its 98 date files with.
  def self.civil(y = -4712, m = 1, d = 1, _start = nil)
    new(y, m, d, _start)
  end

  # --- Julian-day flavours. All exact, so the Rational ones stay Rational. ---
  def ajd = Rational(2 * @jd - 1, 2)
  def amjd = Rational(2 * @jd - 4800002, 2)
  def mjd = @jd - 2400001
  def ld = @jd - 2299160
  def day_fraction = Rational(0, 1)

  # --- the ISO commercial week date -------------------------------------
  # Week 1 is the week holding January 4th, and the week starts on Monday.
  def self.__iso_wday(jd) = ((jd + 1) % 7 == 0 ? 7 : (jd + 1) % 7)

  def self.__monday_of_week1(cwyear)
    j4 = civil_to_jd(cwyear, 1, 4)
    j4 - (__iso_wday(j4) - 1)
  end

  def self.commercial_to_jd(cwyear, cweek, cwday)
    __monday_of_week1(cwyear) + (cweek - 1) * 7 + (cwday - 1)
  end

  def self.commercial(cwyear = -4712, cweek = 1, cwday = 1, _start = nil)
    [cwyear, cweek, cwday].each { |v| raise TypeError, "expected numeric" unless v.is_a?(Numeric) }
    cwyear, cweek, cwday = [cwyear, cweek, cwday].map { |v| v.is_a?(Integer) ? v : (v.to_r.denominator == 1 ? v.to_i : v) }
    raise Date::Error, "invalid date" unless valid_commercial?(cwyear, cweek, cwday)
    # (a negative week or day counts back, as valid_commercial? read them;
    #  the jd was made from the negative numbers themselves)
    cwday += 8 if cwday < 0
    cweek = __weeks_in_cwyear(cwyear) + cweek + 1 if cweek < 0
    jd(commercial_to_jd(cwyear, cweek, cwday), _start)
  end

  def self.valid_commercial?(cwyear, cweek, cwday, _start = nil)
    return false unless cwday.is_a?(Integer) && cweek.is_a?(Integer) && cwyear.is_a?(Integer)
    # 1..7, or -7..-1 counted back from Sunday; 0 is not a day
    cwday += 8 if cwday < 0
    return false if cwday < 1 || cwday > 7
    if cweek < 0
      last = __weeks_in_cwyear(cwyear)
      cweek = last + cweek + 1
    end
    return false if cweek < 1 || cweek > __weeks_in_cwyear(cwyear)
    true
  end

  def self.__weeks_in_cwyear(y)
    (__monday_of_week1(y + 1) - __monday_of_week1(y)) / 7
  end

  def cwday = Date.__iso_wday(@jd)

  def cwyear
    thu = @jd + (4 - Date.__iso_wday(@jd))
    Date.jd_to_civil(thu)[0]
  end

  def cweek
    (@jd - Date.__monday_of_week1(cwyear)) / 7 + 1
  end

  # --- the ordinal (year + day-of-year) date -----------------------------
  def self.ordinal(y = -4712, d = 1, _start = nil)
    [y, d].each { |v| raise TypeError, "expected numeric" unless v.is_a?(Numeric) }
    y, d = [y, d].map { |v| v.is_a?(Integer) ? v : (v.to_r.denominator == 1 ? v.to_i : v) }
    raise Date::Error, "invalid date" unless valid_ordinal?(y, d)
    first = civil_to_jd(y, 1, 1)
    len = civil_to_jd(y + 1, 1, 1) - first
    d = len + d + 1 if d < 0
    jd(first + d - 1, _start)
  end

  def self.valid_ordinal?(y, d, _start = nil)
    return false unless y.is_a?(Integer) && d.is_a?(Integer)
    return false if d == 0
    len = civil_to_jd(y + 1, 1, 1) - civil_to_jd(y, 1, 1)
    d = len + d + 1 if d < 0
    d >= 1 && d <= len
  end

  # --- the remaining validity questions ---------------------------------
  def self.valid_jd?(jd, _start = nil) = jd.is_a?(Numeric)
  def self.valid_date?(y, m, d, _start = nil) = valid_civil?(y, m, d)
  # Date::Infinity: the infinities a Date range can end at
  class Infinity < Numeric
    def initialize(d = 1)
      @d = d <=> 0
    end
    def d = @d
    protected :d
    def zero? = false
    def finite? = false
    def infinite? = @d.nonzero?
    def nan? = @d.zero?
    def abs = self.class.new
    def -@ = self.class.new(-@d)
    def +@ = self.class.new(+@d)
    def <=>(other)
      case other
      when Infinity then @d <=> other.d
      when Numeric then @d
      end
    end
    def coerce(other)
      return [-@d, @d] if other.is_a?(Numeric)
      super
    end
    def to_f
      return 0 if @d == 0
      @d > 0 ? Float::INFINITY : -Float::INFINITY
    end
  end
  # ISO 8601 calendar dates, extended (2008-02-03) and basic (20080203)

  def self.iso8601(str = "-4712-01-01", _start = nil, limit: 128)
    h = _iso8601(str, limit: limit)
    raise Date::Error, "invalid date" if h.empty?
    new(h[:year], h[:mon], h[:mday])
  end
  def self.gregorian_leap?(y) = leap?(y)
  def self.julian_leap?(y) = y % 4 == 0

  # --- iteration ---------------------------------------------------------
  def step(limit, by = 1)
    return to_enum(:step, limit, by) unless block_given?
    raise ArgumentError, "step can't be 0" if by == 0
    d = self
    if by > 0
      while d <= limit
        yield d
        d = d + by
      end
    else
      while d >= limit
        yield d
        d = d + by
      end
    end
    self
  end

  def upto(max, &block)
    return to_enum(:upto, max) unless block_given?
    step(max, 1, &block)
  end

  def downto(min, &block)
    return to_enum(:downto, min) unless block_given?
    step(min, -1, &block)
  end

  # --- the printed forms -------------------------------------------------
  def asctime = strftime("%a %b %e %H:%M:%S %Y")
  alias ctime asctime

  alias_method :xmlschema, :iso8601

  def __off_s
    secs = (__offset * 86400).round
    sign = secs < 0 ? "-" : "+"
    secs = secs.abs
    format("%s%02d:%02d", sign, secs / 3600, (secs % 3600) / 60).force_encoding(Encoding::US_ASCII)
  end

  def rfc3339
    format("%04d-%02d-%02dT%02d:%02d:%02d%s", year, month, day, __hour, __minute, __second, __off_s).force_encoding(Encoding::US_ASCII)
  end

  def rfc2822
    format("%s, %d %s %04d %02d:%02d:%02d +0000",
           Date::ABBR_DAYNAMES[wday], day, Date::ABBR_MONTHNAMES[month], year,
           __hour, __minute, __second).force_encoding(Encoding::US_ASCII)
  end
  alias rfc822 rfc2822

  # Date.rfc2822 / DateTime.rfc2822: "[Day, ]DD Mon YYYY HH:MM[:SS] zone".
  # Anything else -- nil included -- is Date::Error "invalid date", which
  # is what ruby raises; the method did not exist at all.
  def self.rfc2822(str = "Mon, 1 Jan -4712 00:00:00 +0000", _start = nil, limit: 128)
    raise Date::Error, "invalid date" unless str.is_a?(String)
    __limit(str, limit)
    m = /\A\s*(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(-?\d+)\s+(\d{2}):(\d{2})(?::(\d{2}))?/.match(str)
    raise Date::Error, "invalid date" unless m
    mon = Date::ABBR_MONTHNAMES.index(m[2].capitalize)
    raise Date::Error, "invalid date" unless mon
    new(m[3].to_i, mon, m[1].to_i)
  end
  class << self
    alias rfc822 rfc2822
  end

  def httpdate
    format("%s, %02d %s %04d %02d:%02d:%02d GMT",
           Date::ABBR_DAYNAMES[wday], day, Date::ABBR_MONTHNAMES[month], year,
           __hour, __minute, __second).force_encoding(Encoding::US_ASCII)
  end

  # JIS X 0301: the era letter and the year in it, from Meiji 6 (1873-01-01,
  # the day Japan took the Gregorian calendar); an earlier date is ISO 8601
  def __jis_era
    j = jd
    if j >= 2458605 then ["R", 2018]
    elsif j >= 2447535 then ["H", 1988]
    elsif j >= 2424875 then ["S", 1925]
    elsif j >= 2419614 then ["T", 1911]
    elsif j >= 2405160 then ["M", 1867]
    end
  end
  def jisx0301
    era, base = __jis_era
    return iso8601 unless era
    format("%s%02d.%02d.%02d", era, year - base, month, day).force_encoding(Encoding::US_ASCII)
  end

  # --- pattern matching --------------------------------------------------
  def deconstruct_keys(keys)
    unless keys.nil? || keys.is_a?(Array)
      raise TypeError, "wrong argument type #{keys.class} (expected Array or nil)"
    end
    all = { year: year, month: month, day: day, yday: yday, wday: wday }
    return all if keys.nil?
    h = {}
    keys.each { |k| h[k] = all[k] if all.key?(k) }
    h
  end

  def to_datetime = DateTime.new(year, month, day, 0, 0, 0, 0, @start)
  def infinite? = false

  # --- the calendar-reform accessors, for a shim that has ONE calendar ----
  # ⚠ This Date is proleptic Gregorian throughout. `start` can therefore only
  # answer honestly for the one calendar it implements, and the reform-crossing
  # dates (1582-10-05..14) are a KNOWN GAP rather than something these readers
  # paper over: they report Gregorian because that is what was computed.
  def start = 2299161.0
  def julian? = false
  def gregorian? = true
  # `new_start` is a pass-through, the same choice the shim's constructors
  # already make with their ignored `_start` argument: it keeps a caller that
  # passes one working (psych does) without claiming to have changed calendars.
  def new_start(_s = Date::ITALY) = self
  # `gregorian` and `italy` can answer, because Gregorian-with-ITALY is exactly
  # what this Date is and what `start` reports.
  def gregorian = self
  def italy = self
  # ⚠ `england` and `julian` are NOT here, and that is the same rule applied the
  # other way: each names a calendar this implementation does not have, so `self`
  # would be a WRONG answer (`d.england.start` is 2361222 in ruby, and
  # `d.julian.julian?` is true) where a NoMethodError is a missing one.
end
class Date
  # --- the calendar reform -------------------------------------------------
  # Until now this Date was proleptic Gregorian: one formula for all of
  # history, which is right after 1582-10-15 and up to ten days out before it.
  # ruby's Date takes a `start` -- the Julian Day on which the Gregorian
  # calendar took effect -- and uses the JULIAN calendar before it. ITALY
  # (2299161 = 1582-10-15) is the default, so the ten days 1582-10-05..14
  # do not exist at all.
  #
  # The two conversions below are the same shape with different leap rules:
  # Julian has a leap year every four, Gregorian skips three centuries in four.

  def self.julian_to_jd(y, m, d)
    a = (14 - m) / 12
    y2 = y + 4800 - a
    m2 = m + 12 * a - 3
    d + (153 * m2 + 2) / 5 + 365 * y2 + y2 / 4 - 32083
  end

  def self.gregorian_to_jd(y, m, d)
    a = (14 - m) / 12
    y2 = y + 4800 - a
    m2 = m + 12 * a - 3
    d + (153 * m2 + 2) / 5 + 365 * y2 + y2 / 4 - y2 / 100 + y2 / 400 - 32045
  end

  def self.jd_to_julian(jd)
    c = jd + 32082
    d2 = (4 * c + 3) / 1461
    e = c - 1461 * d2 / 4
    m2 = (5 * e + 2) / 153
    [d2 - 4800 + m2 / 10, m2 + 3 - 12 * (m2 / 10), e - (153 * m2 + 2) / 5 + 1]
  end

  def self.jd_to_gregorian(jd)
    a = jd + 32044
    b = (4 * a + 3) / 146097
    c = a - 146097 * b / 4
    d2 = (4 * c + 3) / 1461
    e = c - 1461 * d2 / 4
    m2 = (5 * e + 2) / 153
    [100 * b + d2 - 4800 + m2 / 10, m2 + 3 - 12 * (m2 / 10), e - (153 * m2 + 2) / 5 + 1]
  end

  # `start` decides which side of the reform a JULIAN DAY falls on, so the
  # jd -> civil direction needs no search.
  def self.jd_to_civil(jd, start = ITALY)
    jd >= start ? jd_to_gregorian(jd) : jd_to_julian(jd)
  end

  # ...and civil -> jd needs the answer before it can pick the calendar, so it
  # computes the Gregorian one and keeps it only if it lands on or after the
  # reform. A date that lands before it is Julian instead.
  def self.civil_to_jd(y, m, d, start = ITALY)
    g = gregorian_to_jd(y, m, d)
    return g if g >= start
    julian_to_jd(y, m, d)
  end

  # ⚠ THE TEN DAYS THAT DO NOT EXIST. 1582-10-05..14 convert to a Julian day
  # that is >= start under the Gregorian rule and < start under the Julian
  # one -- they belong to neither calendar, and ruby raises for them. This is
  # the only validity question the proleptic version could not ask.
  def self.valid_civil?(y, m, d, start = ITALY)
    return false unless y.is_a?(Integer) && m.is_a?(Integer) && d.is_a?(Integer)
    m = 13 + m if m < 0
    return false if m < 1 || m > 12
    # a negative day counts back from the month's last day in the calendar
    # the month is in -- October 1582 is 21 days long, so -21 is its 1st.
    if d < 0
      ny, nm = m == 12 ? [y + 1, 1] : [y, m + 1]
      jd = civil_to_jd(ny, nm, 1, start) + d
      cy, cm, _cd = jd_to_civil(jd, start)
      return cy == y && cm == m
    end
    return false if d < 1 || d > 31
    jd = civil_to_jd(y, m, d, start)
    jd_to_civil(jd, start) == [y, m, d]
  end

  # February's length is the one place the two calendars disagree about a
  # MONTH rather than about a day, so the leap rule has to follow `start` too.
  def self.__feb29?(y, start = ITALY)
    return false unless y % 4 == 0
    jd = gregorian_to_jd(y, 3, 1)
    jd >= start ? (y % 100 != 0 || y % 400 == 0) : true
  end

  def self.days_in_month(y, m)
    return 31 if [1, 3, 5, 7, 8, 10, 12].include?(m)
    return 30 if [4, 6, 9, 11].include?(m)
    __feb29?(y) ? 29 : 28
  end

  # ⚠ `Date.leap?` is the GREGORIAN rule whatever the date, and only the
  # INSTANCE `#leap?` follows the calendar its receiver was built on. Making
  # the class method calendar-aware reads as the tidier rule and is wrong:
  # `Date.leap?(1500)` is false in ruby though 1500 was a leap year on the
  # Julian calendar that was in use then.
  def self.leap?(y)
    gregorian_leap?(y)
  end

  def self.gregorian_leap?(y)
    raise TypeError, "expected numeric" unless y.is_a?(Numeric)
    y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
  end
  def self.julian_leap?(y)
    raise TypeError, "expected numeric" unless y.is_a?(Numeric)
    y % 4 == 0
  end

  def self.new(y = -4712, m = 1, d = 1, start = ITALY)
    start = ITALY if start.nil?
    [y, m, d].each { |v| raise TypeError, "expected numeric" unless v.is_a?(Numeric) }
    m = 13 + m if m.is_a?(Integer) && m < 0 && m >= -12
    if d.is_a?(Integer) && d < 0 && m.is_a?(Integer) && m >= 1 && m <= 12 && y.is_a?(Integer)
      len = (m == 2 && __feb29?(y, start)) ? 29 : days_in_month(y, m)
      d = len + d + 1
    end
    raise Date::Error, "invalid date" unless valid_civil?(y, m, d, start)
    allocate.__set_jd(civil_to_jd(y, m, d, start), start)
  end

  def self.civil(y = -4712, m = 1, d = 1, start = ITALY)
    new(y, m, d, start)
  end

  def self.jd(n = 0, start = ITALY)
    start = ITALY if start.nil?
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    allocate.__set_jd(n.to_i, start)
  end

  # --- the instance side: each Date now CARRIES its start ------------------
  def __set_jd(n, start = ITALY)
    @jd = n
    @start = start
    @year, @month, @day = Date.jd_to_civil(n, start)
    self
  end

  def start = @start.nil? ? ITALY.to_f : @start.to_f
  def julian? = @jd < (@start || ITALY)
  def gregorian? = !julian?

  # `new_start` is a real question now: the same instant, read on a calendar
  # whose reform is elsewhere.
  def new_start(s = ITALY)
    s = ITALY if s.nil?
    Date.jd(@jd, s)
  end

  def julian = new_start(Date::JULIAN)
  def gregorian = new_start(Date::GREGORIAN)
  def italy = new_start(Date::ITALY)
  def england = new_start(Date::ENGLAND)

  # arithmetic keeps the calendar it was asked on
  def +(n) = Date.jd(@jd + n.to_i, @start || ITALY)
  def next_day(n = 1) = Date.jd(@jd + n, @start || ITALY)
  def prev_day(n = 1) = Date.jd(@jd - n, @start || ITALY)

  # ⚠ A MONTH STEP CAN LAND IN THE GAP. Clamping the day to the month's
  # length is the ordinary rule (Jan 31 >> 1 is Feb 28), but in the reform
  # month the clamped day can still be one of the ten that do not exist --
  # `Date.civil(1583,10,14).prev_year` is 1582-10-14. ruby walks BACK to the
  # last day that does exist, which is 1582-10-04, so this does too.
  def >>(n)
    # a number of months, floored (<< 1.5 goes back two); nothing else
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    n = n.floor
    st = @start || ITALY
    y = @year
    m = @month + n
    y += (m - 1) / 12
    m = (m - 1) % 12 + 1
    len = (m == 2 && Date.__feb29?(y, st)) ? 29 : Date.days_in_month(y, m)
    d = @day > len ? len : @day
    d -= 1 while d > 1 && !Date.valid_civil?(y, m, d, st)
    Date.new(y, m, d, st)
  end

  def leap? = Date.__feb29?(@year, @start || ITALY)
end

class Date
  # `_rfc3339` and its neighbours answer a HASH of the parts, or an empty one
  # when the string is not that format -- they parse without constructing.
  def self._rfc3339(str, limit: 128)
    __limit(str, limit)
    m = /\A\s*(-?\d+)-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})?\s*\z/.match(str.to_s)
    return {} if m.nil?
    zone = m[7]
    h = { year: m[1].to_i, mon: m[2].to_i, mday: m[3].to_i,
          hour: m[4].to_i, min: m[5].to_i, sec: m[6].to_i }
    return h if zone.nil?
    off = zone == "Z" ? 0 : (zone[1, 2].to_i * 3600 + zone[4, 2].to_i * 60) * (zone[0] == "-" ? -1 : 1)
    h[:zone] = zone
    h[:offset] = off
    h
  end

  # a date and time (RFC 3339's shape), or a calendar date alone,
  # extended (2008-02-03) or basic (20080203); nil is nothing, and
  # something that is not a String is a TypeError
  def self._iso8601(str, limit: 128)
    return {} if str.nil?
    raise TypeError, "no implicit conversion of #{str.class} into String" unless str.respond_to?(:to_str)
    __limit(str.to_str, limit)
    h = _rfc3339(str.to_str, limit: limit)
    return h unless h.empty?
    m = /\A\s*([-+]?\d{4,})-?(\d\d)-?(\d\d)\s*\z/.match(str.to_str)
    m ? { year: m[1].to_i, mon: m[2].to_i, mday: m[3].to_i } : {}
  end
  def self._xmlschema(str, limit: 128) = _rfc3339(str, limit: limit)
  # (the RFC 2822 / HTTP / JIS X 0301 readers: the length limit, then the
  #  general parser -- ruby's are stricter about the shape)
  def self._rfc2822(str, limit: 128)
    __limit(str, limit)
    _parse(str, true, limit: limit)
  end
  def self._httpdate(str, limit: 128)
    __limit(str, limit)
    _parse(str, true, limit: limit)
  end
  def self._jisx0301(str, limit: 128)
    __limit(str, limit)
    _parse(str, true, limit: limit)
  end
  class << self
    alias _rfc822 _rfc2822
  end
  def self.rfc3339(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128)
    __limit(str, limit)
    parse(str, true, start, limit: limit)
  end
  def self.xmlschema(str = "-4712-01-01", start = ITALY, limit: 128)
    __limit(str, limit)
    parse(str, true, start, limit: limit)
  end
  def self.httpdate(str = "Mon, 01 Jan -4712 00:00:00 GMT", start = ITALY, limit: 128)
    __limit(str, limit)
    parse(str, true, start, limit: limit)
  end
  def self.jisx0301(str = "-4712-01-01", start = ITALY, limit: 128)
    __limit(str, limit)
    parse(str, true, start, limit: limit)
  end

  # ⚠ `valid_civil?` and `valid_date?` are ONE method under two names, and
  # the spec reads `Date.method(:valid_civil?) == Date.method(:valid_date?)`.
  # Two definitions with identical bodies answer the same values and fail that.
  class << self
    alias_method :valid_date?, :valid_civil?
  end

  # `+` takes a number. Anything else is a TypeError naming what was wanted,
  # not a NoMethodError from whatever the argument failed to answer.
  def +(n)
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    Date.jd(@jd + n.to_i, @start || ITALY)
  end

  def -(other)
    return Date.jd(@jd - other.to_i, @start || ITALY) if other.is_a?(Numeric)
    return Rational(@jd - other.jd, 1) if other.is_a?(Date)
    raise TypeError, "expected numeric or date"
  end
end

# DateTime keeps its time as whole fields plus an exact fraction of a
# second, and does its arithmetic in (Rational) seconds: + and - move by
# a fraction of a day, and a difference is a fraction of a day. It used
# to inherit Date's whole-day arithmetic, so `+ 0.5` did nothing.
class DateTime < Date
  def self.civil(y = -4712, m = 1, d = 1, h = 0, min = 0, s = 0, off = 0, start = nil)
    new(y, m, d, h, min, s, off, start)
  end

  def self.parse(str = "-4712-01-01T00:00:00+00:00", comp = true, _start = nil, limit: 128)
    h = Date._parse(str, comp, limit: limit)
    raise Date::Error, "invalid date" if h.empty?
    y, m, d = Date.__parsed_civil(h)
    raise Date::Error, "invalid date" unless Date.valid_civil?(y, m, d)
    hr, mi, se = h[:hour] || 0, h[:min] || 0, h[:sec] || 0
    raise Date::Error, "invalid date" if hr > 24 || mi > 59 || se > 60
    new(y, m, d, hr, mi, se)
  end

  def __set_time(h, mi, s)
    @hour = h
    @minute = mi
    if s.is_a?(Integer)
      @second = s
      @sec_frac = Rational(0, 1)
    else
      r = s.is_a?(Float) ? s.rationalize : Rational(s)
      @second = r.floor
      @sec_frac = r - @second
    end
    self
  end

  def sec_fraction = @sec_frac || Rational(0, 1)
  alias_method :second_fraction, :sec_fraction
  def day_fraction = Rational(hour * 3600 + minute * 60 + second, 86400) + sec_fraction / 86400

  # seconds since jd 0, on the local clock and on UTC
  def __local_seconds = jd * 86400 + hour * 3600 + minute * 60 + second + sec_fraction
  def __utc_seconds = __local_seconds - offset * 86400

  def self.__from_local(total, off, start = nil)
    j = (total / 86400).floor
    rem = total - j * 86400
    h = (rem / 3600).floor
    rem -= h * 3600
    mi = (rem / 60).floor
    sec = rem - mi * 60
    y, m, d = Date.jd_to_civil(j)
    new(y, m, d, h, mi, sec.denominator == 1 ? sec.to_i : sec, off, start)
  end

  def +(n)
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    days = n.is_a?(Float) ? n.rationalize : Rational(n)
    DateTime.__from_local(__local_seconds + days * 86400, offset, @start)
  end

  def -(other)
    return self + (-other) if other.is_a?(Numeric)
    if other.is_a?(DateTime)
      return Rational(__utc_seconds - other.__utc_seconds, 86400)
    end
    return Rational(__utc_seconds - other.jd * 86400, 86400) if other.is_a?(Date)
    raise TypeError, "expected numeric or date"
  end

  # Time's calendar is always the Gregorian one
  def to_time
    gy, gm, gd = Date.jd_to_gregorian(jd)
    Time.new(gy, gm, gd, hour, minute, second + sec_fraction, __off_s)
  end

  def deconstruct_keys(keys)
    unless keys.nil? || keys.is_a?(Array)
      raise TypeError, "wrong argument type #{keys.class} (expected Array or nil)"
    end
    all = { year: year, month: month, day: day, yday: yday, wday: wday, hour: hour, min: minute,
            sec: second, sec_fraction: sec_fraction, zone: zone }
    return all if keys.nil?
    h = {}
    keys.each { |k| h[k] = all[k] if all.key?(k) }
    h
  end

  # the day number, seconds and nanoseconds on UTC, the offset and the reform
  def inspect
    u = __utc_seconds
    j = (u / 86400).floor
    secs = u - j * 86400
    whole = secs.floor
    ns = ((secs - whole) * 1_000_000_000).floor
    offs = (offset * 86400).round
    st = start
    sts = st.infinite? ? (st < 0 ? "-Inf" : "Inf") : st.to_i.to_s
    "#<DateTime: #{self} ((#{j}j,#{whole}s,#{ns}n),#{offs < 0 ? '-' : '+'}#{offs.abs}s,#{sts}j)>".force_encoding(Encoding::US_ASCII)
  end

  # the one strftime engine, with the time of day, the fraction and the
  # offset this DateTime carries
  def strftime(fmt = "%FT%T%:z")
    Date.__strf_range_check(fmt, year)
    r = Time.__strf(fmt, [year, month, day, yday, wday, hour, minute, second, sec_fraction,
                          (offset * 86400).round, false, zone, __utc_seconds - 2440588 * 86400, true])
    r.ascii_only? ? r.force_encoding(Encoding::US_ASCII) : r
  end
  def jisx0301(n = 0)
    era, base = __jis_era
    head = era ? format("%s%02d.%02d.%02d", era, year - base, month, day) : Date.instance_method(:to_s).bind(self).call
    (head + strftime("T%H:%M:%S") + (n > 0 ? strftime(".%#{n}N") : "") + __off_s).force_encoding(Encoding::US_ASCII)
  end
  def to_datetime = self
  def to_date = Date.new(year, month, day, @start || Date::ITALY)
end

# DateTime.new as date_core's datetime_s_civil checks it. ⚠ It took any
# fields: an hour of -10 stayed -10, 25 and 1.5 were accepted, a Rational
# day was dropped. A fraction is allowed only in the LAST argument given
# (num2int_with_frac), where it carries into the fields below; a negative
# hour, minute or second counts back from the end of the day, hour or
# minute; hour 24 is the next day's midnight; and anything else is
# Date::Error "invalid date".
class DateTime
  class << self
    alias_method :__new_fields, :new
  end

  def self.new(*args)
    if args.size > 8
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..8)"
    end
    y, m, d, h, mi, s, off, _st = args
    n = args.size
    y = -4712 if y.nil?
    m = 1 if m.nil?
    d = 1 if d.nil?
    h = 0 if h.nil?
    mi = 0 if mi.nil?
    s = 0 if s.nil?
    off = 0 if off.nil?
    split = lambda do |v, pos|
      next [v, 0] if v.is_a?(Integer)
      r = v.is_a?(Numeric) ? v.to_r : v
      i = r.floor
      fr = r - i
      raise Date::Error, "invalid fraction" if fr != 0 && n > pos
      [i, fr]
    end
    d, dfr = split.(d, 3)
    h, hfr = split.(h, 4)
    mi, mfr = split.(mi, 5)
    si, sfr = split.(s, 99)
    h += 24 if h < 0
    mi += 60 if mi < 0
    si += 60 if si < 0
    if h < 0 || h > 24 || mi < 0 || mi > 59 || si < 0 || si > 59 || (h == 24 && (mi > 0 || si > 0))
      raise Date::Error, "invalid date"
    end
    next_day = h == 24
    h = 0 if next_day
    obj = __new_fields(y, m, d, h, mi, sfr == 0 ? si : si + sfr, off, _st)
    obj += 1 if next_day
    carry = dfr * 86400 + hfr * 3600 + mfr * 60
    obj += Rational(carry, 86400) if carry != 0
    obj
  end

  # DateTime.jd with the time of day: the calendar day of that Julian Day
  # (read in `start`'s calendar), then its clock
  def self.jd(jd = 0, h = 0, min = 0, s = 0, off = 0, start = Date::ITALY)
    d = Date.jd(jd, start)
    new(d.year, d.month, d.day, h, min, s, off)
  end
end

# date's own additions to Time: the day, and the instant, in the default
# calendar reform. The Julian Day comes from Time's proleptic Gregorian
# fields; the civil fields a Date then shows are its own calendar's.
class Time
  def to_date = Date.jd(Date.civil_to_jd(year, mon, mday, Date::GREGORIAN))

  def to_datetime
    DateTime.jd(Date.civil_to_jd(year, mon, mday, Date::GREGORIAN), hour, min, sec + subsec, Rational(utc_offset, 86400))
  end
end

# Marshal, as ruby's d_lite_marshal_dump writes it: [nth, jd, df, sf, of, sg]
# -- the Julian Day on UTC, the seconds into that day, the fraction of a
# second in nanoseconds, the offset in seconds and the calendar reform.
# marshal_load reads that and the two older shapes ([ajd, sg] of ruby 1.6,
# [ajd, of, sg] of 1.8), which Date._load (Marshal's `u` type) hands it.
class Date
  def marshal_dump
    [0, jd, 0, 0, 0, start]
  end

  def marshal_load(a)
    raise FrozenError, "can't modify frozen #{self.class}: #{inspect}" if frozen?
    raise TypeError, "expected an array" unless a.is_a?(Array)
    jd, df, sf, of, sg =
      case a.size
      when 2, 3
        ajd, vof, vsg = (a.size == 2 ? [a[0] - Rational(1, 2), 0, a[1]] : a)
        vsg = (vsg ? Date::GREGORIAN : Date::JULIAN) unless vsg.is_a?(Numeric)
        # (the old shapes' ajd is UTC, as the six-field one's jd and df are)
        t = (ajd + Rational(1, 2)) * 86400
        j = (t / 86400).floor
        secs = t - j * 86400
        [j, secs.floor, (secs - secs.floor) * 1_000_000_000, (vof * 86400).round, vsg]
      when 6 then [a[1], a[2], a[3], a[4], a[5]]
      else raise TypeError, "invalid size"
      end
    __marshal_set(jd, df, sf, of, sg)
    self
  end

  def __marshal_set(jd, df, sf, of, sg)
    __set_jd(jd, sg)
  end

  def self._load(s) = allocate.marshal_load(Marshal.load(s))

  # initialize_copy takes any Date, a DateTime included (d_lite_initialize_copy)
  def initialize_copy(other)
    raise TypeError, "expected date" unless other.is_a?(Date)
    # (the whole state is the other's: a DateTime copied from a Date is
    #  that date's midnight)
    instance_variables.each { |iv| remove_instance_variable(iv) }
    other.instance_variables.each { |iv| instance_variable_set(iv, other.instance_variable_get(iv)) }
    self
  end
end

class DateTime < Date
  def marshal_dump
    u = __utc_seconds
    j = (u / 86400).floor
    secs = u - j * 86400
    df = secs.floor
    sf = (secs - df) * 1_000_000_000
    sf = sf.to_i if sf.is_a?(Rational) && sf.denominator == 1
    [0, j, df, sf, (offset * 86400).round, start]
  end

  def __marshal_set(jd, df, sf, of, sg)
    src = DateTime.__from_local(jd * 86400 + df + Rational(sf, 1_000_000_000) + of, Rational(of, 86400), sg)
    src.instance_variables.each { |iv| instance_variable_set(iv, src.instance_variable_get(iv)) }
  end

  # the ordinal and commercial constructors with a time of day, as Date's
  # with the clock fields DateTime.new takes (a negative one counts back)
  def self.ordinal(y = -4712, d = 1, h = 0, min = 0, s = 0, off = 0, start = Date::ITALY)
    dd = Date.ordinal(y, d, start)
    new(dd.year, dd.month, dd.day, h, min, s, off, start)
  end

  def self.commercial(cwyear = -4712, cweek = 1, cwday = 1, h = 0, min = 0, s = 0, off = 0, start = Date::ITALY)
    dd = Date.commercial(cwyear, cweek, cwday, start)
    new(dd.year, dd.month, dd.day, h, min, s, off, start)
  end
end


# ===========================================================================
# THE MODEL, ONCE, for Date and DateTime alike (date_core.c's, read back).
#
# Every instance holds the same five things, as ruby's ComplexDateData does,
# but LOCAL rather than UTC:
#
#   @jd     the Julian Day on the local clock (an Integer, any size)
#   @df     the seconds into that day, 0...86400
#   @sf     the fraction of that second, a Rational in [0, 1)
#   @of     the offset from UTC in whole seconds (-86400..86400)
#   @start  the calendar reform, a Float (a Julian Day, or +-Infinity)
#
# and @year/@month/@day, the civil date of @jd read on @start's calendar.
# A Date is the same object with @df, @sf and @of zero -- until arithmetic
# gives it a fraction, which ruby keeps (`Date.new(2004,9,19) + 1r/2` has a
# day_fraction of 1/2). Every instance has the same eight instance
# variables, so a DateTime overwritten by initialize_copy from a Date keeps
# its size (test_memsize).
#
# ⚠ THE LAYERS ABOVE HELD FOUR SHAPES. A Date had @jd and the civil fields;
#   a DateTime had those plus @hour/@minute/@second/@sec_frac/@offset; the
#   calendar was right for Date.new and ignored by DateTime.new (whose
#   `start` was never passed down), so DateTime.new(..., Date::JULIAN) was a
#   Gregorian date and test_period2 was 80 quintillion days out; arithmetic
#   built through Date.jd / DateTime.new by NAME, so a DateSub + 1 was a Date
#   and a DateTime + 1/2 lost its fraction of a second. Everything below
#   builds through `self.class.allocate.__init`.
# ===========================================================================
class Date
  # ⚠ ONE GUARD for every `start` argument (date_core's val2sg): a number,
  #   +-Infinity or a Julian Day inside ruby's reform window; anything else
  #   is warned about and replaced by ITALY. nil is ITALY too: the shim's own
  #   callers pass it for "the default".
  def self.__sg(sg)
    return ITALY.to_f if sg.nil?
    raise TypeError, "no implicit conversion to float from #{sg.class}" unless sg.is_a?(Numeric)
    f = sg.to_f
    if f.nan? || (!f.infinite? && (f < 2298874 || f > 2426355))
      warn("warning: invalid start is ignored") if $VERBOSE
      return ITALY.to_f
    end
    f
  end

  def self.__num!(v, name)
    raise TypeError, "invalid #{name} (not numeric)" unless v.is_a?(Numeric)
    v
  end

  def self.__int(v) = v.is_a?(Integer) ? v : v.to_i

  def self.__whole?(v)
    case v
    when Integer then true
    when Float then v.finite? && v.round == v
    when Rational then v.denominator == 1
    else false
    end
  end

  # the whole part of an argument and what it leaves over, IN DAYS (`unit`
  # is how many of the argument make a day: 24 hours, 1440 minutes ...),
  # as d_trunc / h_trunc / min_trunc / s_trunc split them
  def self.__trunc(v, unit)
    return [v, 0] if v.is_a?(Integer)
    return [v.to_i, 0] if __whole?(v)
    i = v.div(1)
    fr = v % 1
    fr = fr.quo(unit) if unit != 1
    [i, fr]
  end

  # --- the calendars, every question asked of a `start` --------------------
  # A civil date is valid when it goes to a Julian Day and comes back the
  # same (1582-10-10 does not, under ITALY). A negative month counts back
  # from December, a negative day from the month's last day -- the last day
  # THAT EXISTS, which c_find_ldom finds by trying 31, 30, ...
  def self.__valid_civil_jd(y, m, d, sg)
    m += 13 if m < 0
    return nil if m < 1 || m > 12
    if d < 0
      l = __find_ldom(y, m, sg)
      return nil if l.nil?
      y2, m2, d2 = jd_to_civil(l + d + 1, sg)
      return nil unless y2 == y && m2 == m
      d = d2
    end
    jd = civil_to_jd(y, m, d, sg)
    y2, m2, d2 = jd_to_civil(jd, sg)
    return nil unless y2 == y && m2 == m && d2 == d
    jd
  end

  def self.__find_ldom(y, m, sg)
    d = 31
    while d > 0
      j = __valid_civil_jd(y, m, d, sg)
      return j if j
      d -= 1
    end
    nil
  end

  # the first and last days of a year, which the reform can move
  def self.__fdoy(y, sg)
    g = gregorian_to_jd(y, 1, 1)
    return g if g >= sg
    j = julian_to_jd(y, 1, 1)
    return j if j < sg
    d = 2
    while d <= 30
      jd = __valid_civil_jd(y, 1, d, sg)
      return jd if jd
      d += 1
    end
    nil
  end

  def self.__ldoy(y, sg)
    i = 0
    while i < 30
      jd = __valid_civil_jd(y, 12, 31 - i, sg)
      return jd if jd
      i += 1
    end
    nil
  end

  def self.__jd_to_ordinal(jd, sg)
    y = jd_to_civil(jd, sg)[0]
    [y, jd - __fdoy(y, sg) + 1]
  end

  def self.__valid_ordinal_jd(y, d, sg)
    if d < 0
      l = __ldoy(y, sg)
      return nil if l.nil?
      y2, d2 = __jd_to_ordinal(l + d + 1, sg)
      return nil unless y2 == y
      d = d2
    end
    f = __fdoy(y, sg)
    return nil if f.nil?
    jd = f + d - 1
    y2, d2 = __jd_to_ordinal(jd, sg)
    return nil unless y2 == y && d2 == d
    jd
  end

  # ISO weeks: week 1 holds the year's first Thursday (its 4th of January)
  def self.__commercial_jd(y, w, d, sg)
    r = __fdoy(y, sg) + 3
    (r - r % 7) + 7 * (w - 1) + (d - 1)
  end

  def self.__jd_to_commercial(jd, sg)
    a = jd_to_civil(jd - 3, sg)[0]
    r = __fdoy(a + 1, sg) + 3
    y = jd >= r - r % 7 ? a + 1 : a
    r = __fdoy(y, sg) + 3
    w = 1 + (jd - (r - r % 7)).div(7)
    d = (jd + 1) % 7
    [y, w, d == 0 ? 7 : d]
  end

  def self.__valid_commercial_jd(y, w, d, sg)
    d += 8 if d < 0
    if w < 0
      y2, w2, _d2 = __jd_to_commercial(__commercial_jd(y + 1, 1, 1, sg) + w * 7, sg)
      return nil unless y2 == y
      w = w2
    end
    jd = __commercial_jd(y, w, d, sg)
    y2, w2, d2 = __jd_to_commercial(jd, sg)
    return nil unless y2 == y && w2 == w && d2 == d
    jd
  end

  # %U / %W weeks (f = 0: weeks from Sunday, 1: from Monday), as strptime's
  # fields name them
  def self.__weeknum_jd(y, w, d, f, sg)
    r = __fdoy(y, sg) + 6
    (r - (r - f + 1) % 7 - 7) + 7 * w + d
  end

  def self.__jd_to_weeknum(jd, f, sg)
    y = jd_to_civil(jd, sg)[0]
    r = __fdoy(y, sg) + 6
    j = jd - (r - (r - f + 1) % 7) + 7
    [y, j.div(7), j % 7]
  end

  def self.__valid_weeknum_jd(y, w, d, f, sg)
    d += 7 if d < 0
    if w < 0
      y2, w2, _d2 = __jd_to_weeknum(__weeknum_jd(y + 1, 1, f, f, sg) + w * 7, f, sg)
      return nil unless y2 == y
      w = w2
    end
    jd = __weeknum_jd(y, w, d, f, sg)
    y2, w2, d2 = __jd_to_weeknum(jd, f, sg)
    return nil unless y2 == y && w2 == w && d2 == d
    jd
  end

  # the time of day as c_valid_time_p takes it: a negative field counts back
  # from the end of the day, hour or minute, and 24:00:00 is allowed
  def self.__valid_time(h, mi, s)
    h += 24 if h < 0
    mi += 60 if mi < 0
    s += 60 if s < 0
    return nil if h < 0 || h > 24 || mi < 0 || mi > 59 || s < 0 || s > 59 || (h == 24 && (mi > 0 || s > 0))
    [h, mi, s]
  end

  # --- offsets --------------------------------------------------------------
  # A zone name or a numeric offset, in seconds east of UTC, as
  # date_zone_to_diff reads it; nil when it is neither.
  def self.__zones
    @__zones ||= begin
      h = {}
      __zone_src.join(";").split(";").each do |e|
        k, v = e.split("=")
        h[k] = v.to_i
      end
      h
    end
  end

  def self.__zone_to_diff(str)
    s = str.to_s
    dst = false
    low = s.downcase
    if (m = /\A(.*?)\s+(standard|daylight)\s+time\z/.match(low))
      low = m[1]
      dst = m[2] == "daylight"
      s = s[0, m[1].size]
    elsif (m = /\A(.*?)\s+dst\z/.match(low))
      low = m[1]
      dst = true
      s = s[0, m[1].size]
    end
    key = low.strip.gsub(/\s+/, " ")
    if (o = __zones[key])
      return dst ? o + 3600 : o
    end
    s = s[3..] if s.size > 3 && /\A(gmt|utc)/i.match?(s)
    return nil unless s[0] == "+" || s[0] == "-"
    neg = s[0] == "-"
    s = s[1..]
    hs = s[/\A\d*/]
    rest = s[hs.size..]
    if rest.start_with?(":")
      hour = hs.to_i
      return nil if hour > 23
      rest = rest[1..]
      ms = rest[/\A\d*/]
      min = ms.to_i
      return nil if min > 59
      rest = rest[ms.size..]
      sec = 0
      if rest.start_with?(":")
        sec = rest[1..][/\A\d*/].to_i
        return nil if sec > 59
      end
      off = hour * 3600 + min * 60 + sec
    elsif rest.start_with?(",") || rest.start_with?(".")
      hour = hs.to_i
      return nil if hour > 23
      digits = rest[1..]
      ds = digits[/\A\d*/][0, 7]
      n = ds.size
      sec = ds.to_i
      nxt = digits[n]
      sec += 1 if nxt && nxt >= (sec.odd? ? "5" : "6") && nxt <= "9"
      sec *= 36
      if neg
        hour = -hour
        sec = -sec
      end
      if n <= 2
        sec *= 10 if n == 1
        return sec + hour * 3600
      end
      r = Rational(sec, 10**(n - 2)) + hour * 3600
      return r.denominator == 1 ? r.to_i : r
    else
      l = s.size
      hour = hs.to_i
      min = 0
      sec = 0
      if l > 2
        hour = s[0, 2 - l % 2][/\A\d*/].to_i
        min = s[2 - l % 2, 2].to_s[/\A\d*/].to_i if l >= 3
        sec = s[4 - l % 2, 2].to_s[/\A\d*/].to_i if l >= 5
      end
      off = hour * 3600 + min * 60 + sec
    end
    neg ? -off : off
  end

  # offset_to_sec: a fraction of a day (-1, 0 and 1 for an Integer), or a
  # String; nil for one out of range. Something that is not a number is a
  # TypeError, and so is a Numeric whose to_r is not a Rational (it was a
  # loop that never ended).
  def self.__offset_to_sec(v)
    case v
    when Integer
      return nil unless v == -1 || v == 0 || v == 1
      v * 86400
    when Float
      n = v * 86400
      return nil if n < -86400 || n > 86400
      r = n.round
      warn("warning: fraction of offset is ignored") if $VERBOSE && r != n
      r
    when String
      s = __zone_to_diff(v)
      return nil unless s.is_a?(Integer) && s >= -86400 && s <= 86400
      s
    else
      raise TypeError, "expected numeric" unless v.is_a?(Numeric)
      r = v.is_a?(Rational) ? v : v.to_r
      r = r.to_r if r.is_a?(Integer)
      raise TypeError, "wrong argument type #{r.class} (expected Rational)" unless r.is_a?(Rational)
      secs = r * 86400
      if secs.denominator == 1
        n = secs.numerator
      else
        n = secs.round
        warn("warning: fraction of offset is ignored") if $VERBOSE
      end
      return nil if n < -86400 || n > 86400
      n
    end
  end

  def self.__val2off(v)
    o = __offset_to_sec(v)
    if o.nil?
      warn("warning: invalid offset is ignored") if $VERBOSE
      o = 0
    end
    o
  end

  # --- building ---------------------------------------------------------------
  def __init(jd, df, sf, of, sg)
    @jd = jd
    @df = df
    @sf = sf
    @of = of
    @start = sg
    @year, @month, @day = Date.jd_to_civil(jd, sg)
    self
  end

  # the parts, for another instance's comparisons
  def __df = @df
  def __sf = @sf
  def __of = @of
  def __utc_day_secs = @jd * 86400 + @df - @of
  def __utc_secs = @jd * 86400 + @df - @of + @sf

  # (the earlier layers' setters, kept for any caller they had)
  def __set_jd(n, start = ITALY) = __init(n, 0, Rational(0, 1), 0, Date.__sg(start))
  def __set_time(h, mi, s)
    t = h * 3600 + mi * 60 + s
    @df = t.floor
    @sf = (t - @df).to_r
    self
  end
  def __set_offset(o)
    @of = (o * 86400).round
    self
  end

  def self.new(y = -4712, m = 1, d = 1, sg = ITALY)
    sg = __sg(sg)
    __num!(d, "day")
    __num!(m, "month")
    __num!(y, "year")
    d, fr = __trunc(d, 1)
    jd = __valid_civil_jd(__int(y), __int(m), d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    r = allocate.__init(jd, 0, Rational(0, 1), 0, sg)
    fr == 0 ? r : r + fr
  end

  def self.civil(y = -4712, m = 1, d = 1, sg = ITALY) = new(y, m, d, sg)

  def self.jd(jd = 0, sg = ITALY)
    sg = __sg(sg)
    __num!(jd, "jd")
    j, fr = __trunc(jd, 1)
    r = allocate.__init(j, 0, Rational(0, 1), 0, sg)
    fr == 0 ? r : r + fr
  end

  def self.ordinal(y = -4712, d = 1, sg = ITALY)
    sg = __sg(sg)
    __num!(d, "yday")
    __num!(y, "year")
    d, fr = __trunc(d, 1)
    jd = __valid_ordinal_jd(__int(y), d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    r = allocate.__init(jd, 0, Rational(0, 1), 0, sg)
    fr == 0 ? r : r + fr
  end

  def self.commercial(y = -4712, w = 1, d = 1, sg = ITALY)
    sg = __sg(sg)
    __num!(d, "cwday")
    __num!(w, "cweek")
    __num!(y, "year")
    d, fr = __trunc(d, 1)
    jd = __valid_commercial_jd(__int(y), __int(w), d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    r = allocate.__init(jd, 0, Rational(0, 1), 0, sg)
    fr == 0 ? r : r + fr
  end

  def self.today(sg = ITALY)
    sg = __sg(sg)
    t = Time.now
    allocate.__init(gregorian_to_jd(t.year, t.mon, t.mday), 0, Rational(0, 1), 0, sg)
  end

  def self.commercial_to_jd(y, w, d, sg = ITALY) = __commercial_jd(y, w, d, __sg(sg))

  def self.valid_jd?(jd, _sg = ITALY) = jd.is_a?(Numeric)

  def self.valid_civil?(y, m, d, sg = ITALY)
    return false unless y.is_a?(Numeric) && m.is_a?(Numeric) && d.is_a?(Numeric)
    !__valid_civil_jd(__int(y), __int(m), __int(d), __sg(sg)).nil?
  end

  def self.valid_ordinal?(y, d, sg = ITALY)
    return false unless y.is_a?(Numeric) && d.is_a?(Numeric)
    !__valid_ordinal_jd(__int(y), __int(d), __sg(sg)).nil?
  end

  def self.valid_commercial?(y, w, d, sg = ITALY)
    return false unless y.is_a?(Numeric) && w.is_a?(Numeric) && d.is_a?(Numeric)
    !__valid_commercial_jd(__int(y), __int(w), __int(d), __sg(sg)).nil?
  end

  class << self
    alias_method :valid_date?, :valid_civil?
  end

  # --- what a set of parsed fields names (d_new_by_frags) ---------------------
  # `seconds` (strptime's %s / %Q) becomes a day and a time of day ...
  def self.__rewrite_frags(h)
    seconds = h.delete(:seconds)
    return h if seconds.nil?
    seconds += h[:offset] if h[:offset]
    d = seconds.div(86400)
    fr = seconds % 86400
    h[:jd] = 2440588 + d
    h[:hour] = fr.div(3600)
    fr %= 3600
    h[:min] = fr.div(60)
    fr %= 60
    h[:sec] = fr.div(1)
    h[:sec_fraction] = fr % 1
    h
  end

  def self.__frag_tab
    @__frag_tab ||= [
      [:time, [:hour, :min, :sec]],
      [nil, [:jd]],
      [:ordinal, [:year, :yday, :hour, :min, :sec]],
      [:civil, [:year, :mon, :mday, :hour, :min, :sec]],
      [:commercial, [:cwyear, :cweek, :cwday, :hour, :min, :sec]],
      [:wday, [:wday, :hour, :min, :sec]],
      [:wnum0, [:year, :wnum0, :wday, :hour, :min, :sec]],
      [:wnum1, [:year, :wnum1, :wday, :hour, :min, :sec]],
      [nil, [:cwyear, :cweek, :wday, :hour, :min, :sec]],
      [nil, [:year, :wnum0, :cwday, :hour, :min, :sec]],
      [nil, [:year, :wnum1, :cwday, :hour, :min, :sec]]
    ]
  end

  # ... and what is missing is taken from today, by the pattern the fields
  # given fit best (rt_complete_frags)
  def self.__complete_frags(klass, h)
    k = nil
    a = nil
    e = 0
    __frag_tab.each do |key, fields|
      n = fields.count { |f| !h[f].nil? }
      if n > e
        e = n
        k = key
        a = fields
      end
    end
    today = nil
    if k && a.size > e
      case k
      when :ordinal
        h[:year] = (today ||= Date.today).year if h[:year].nil?
        h[:yday] = 1 if h[:yday].nil?
      when :civil, :commercial, :wnum0, :wnum1
        a.each do |f|
          break unless h[f].nil?
          h[f] = (today ||= Date.today).__send__(f)
        end
        case k
        when :civil
          h[:mon] = 1 if h[:mon].nil?
          h[:mday] = 1 if h[:mday].nil?
        when :commercial
          h[:cweek] = 1 if h[:cweek].nil?
          h[:cwday] = 1 if h[:cwday].nil?
        when :wnum0
          h[:wnum0] = 0 if h[:wnum0].nil?
          h[:wday] = 0 if h[:wday].nil?
        when :wnum1
          h[:wnum1] = 0 if h[:wnum1].nil?
          h[:wday] = 1 if h[:wday].nil?
        end
      when :wday
        today ||= Date.today
        h[:jd] = (today - today.wday + h[:wday]).jd
      end
    end
    if k == :time && klass <= DateTime
      h[:jd] = (today ||= Date.today).jd if h[:jd].nil?
    end
    h[:hour] = 0 if h[:hour].nil?
    h[:min] = 0 if h[:min].nil?
    if h[:sec].nil?
      h[:sec] = 0
    elsif h[:sec] > 59
      h[:sec] = 59
    end
    h
  end

  def self.__valid_date_frags(h, sg)
    return h[:jd] unless h[:jd].nil?
    if !h[:yday].nil? && !h[:year].nil?
      jd = __valid_ordinal_jd(__int(h[:year]), __int(h[:yday]), sg)
      return jd if jd
    end
    if !h[:mday].nil? && !h[:mon].nil? && !h[:year].nil?
      jd = __valid_civil_jd(__int(h[:year]), __int(h[:mon]), __int(h[:mday]), sg)
      return jd if jd
    end
    wd = h[:cwday]
    if wd.nil?
      wd = h[:wday]
      wd = 7 if !wd.nil? && wd == 0
    end
    if !wd.nil? && !h[:cweek].nil? && !h[:cwyear].nil?
      jd = __valid_commercial_jd(__int(h[:cwyear]), __int(h[:cweek]), __int(wd), sg)
      return jd if jd
    end
    wd = h[:wday]
    if wd.nil?
      wd = h[:cwday]
      wd = 0 if !wd.nil? && wd == 7
    end
    if !wd.nil? && !h[:wnum0].nil? && !h[:year].nil?
      jd = __valid_weeknum_jd(__int(h[:year]), __int(h[:wnum0]), __int(wd), 0, sg)
      return jd if jd
    end
    wd = h[:wday]
    wd = h[:cwday] if wd.nil?
    wd = (wd - 1) % 7 unless wd.nil?
    if !wd.nil? && !h[:wnum1].nil? && !h[:year].nil?
      jd = __valid_weeknum_jd(__int(h[:year]), __int(h[:wnum1]), __int(wd), 1, sg)
      return jd if jd
    end
    nil
  end

  def self.__new_by_frags(h, sg)
    sg = __sg(sg)
    raise Date::Error, "invalid date" if h.nil?
    h = h.dup
    if h[:jd].nil? && h[:yday].nil? && !h[:year].nil? && !h[:mon].nil? && !h[:mday].nil?
      jd = __valid_civil_jd(__int(h[:year]), __int(h[:mon]), __int(h[:mday]), sg)
    else
      __rewrite_frags(h)
      __complete_frags(self, h)
      jd = __valid_date_frags(h, sg)
    end
    raise Date::Error, "invalid date" if jd.nil?
    allocate.__init(jd, 0, Rational(0, 1), 0, sg)
  end

  # the constructors from the format readers (date_s_iso8601 and kin): the
  # reader's fields, then the same completion Date.parse does
  def self.iso8601(str = "-4712-01-01", sg = ITALY, limit: 128) = __new_by_frags(_iso8601(str, limit: limit), sg)
  def self.rfc3339(str = "-4712-01-01T00:00:00+00:00", sg = ITALY, limit: 128) = __new_by_frags(_rfc3339(str, limit: limit), sg)
  def self.xmlschema(str = "-4712-01-01", sg = ITALY, limit: 128) = __new_by_frags(_xmlschema(str, limit: limit), sg)
  def self.rfc2822(str = "Mon, 1 Jan -4712 00:00:00 +0000", sg = ITALY, limit: 128) = __new_by_frags(_rfc2822(str, limit: limit), sg)
  def self.httpdate(str = "Mon, 01 Jan -4712 00:00:00 GMT", sg = ITALY, limit: 128) = __new_by_frags(_httpdate(str, limit: limit), sg)
  def self.jisx0301(str = "-4712-01-01", sg = ITALY, limit: 128) = __new_by_frags(_jisx0301(str, limit: limit), sg)
  class << self
    alias_method :rfc822, :rfc2822
  end

  # --- reading ------------------------------------------------------------
  attr_reader :jd, :year
  def mon = @month
  def month = @month
  def mday = @day
  def day = @day
  def start = @start
  def wday = (@jd + 1) % 7
  def yday = @jd - Date.__fdoy(@year, @start) + 1
  def cwday = (w = (@jd + 1) % 7) == 0 ? 7 : w
  def cwyear = Date.__jd_to_commercial(@jd, @start)[0]
  def cweek = Date.__jd_to_commercial(@jd, @start)[1]
  def julian? = @jd < @start
  def gregorian? = !julian?
  def leap?
    return Date.gregorian_leap?(@year) if gregorian?
    Date.jd_to_civil(Date.civil_to_jd(@year, 3, 1, @start) - 1, @start)[2] == 29
  end

  def ajd
    return Rational(2 * @jd - 1, 2) if @df == 0 && @of == 0 && @sf == 0
    __utc_secs.to_r / 86400 - Rational(1, 2)
  end
  def amjd = ajd - Rational(4800001, 2)
  def mjd = @jd - 2400001
  def ld = @jd - 2299160
  # (0 for a plain Date, as ruby's "simple" one answers; a Rational once it
  #  has a time of day)
  def day_fraction
    return 0 if @df == 0 && @sf == 0
    (@df + @sf).to_r / 86400
  end

  # --- the same instant on another calendar --------------------------------
  def new_start(sg = ITALY) = self.class.allocate.__init(@jd, @df, @sf, @of, Date.__sg(sg))
  def italy = new_start(ITALY)
  def england = new_start(ENGLAND)
  def julian = new_start(JULIAN)
  def gregorian = new_start(GREGORIAN)

  # --- arithmetic (d_lite_plus / d_lite_minus / d_lite_rshift) ----------------
  # A whole number moves the day; a Rational is exact to any precision; a
  # Float is taken as days, seconds and nanoseconds, the last rounded.
  def +(other)
    case other
    when Integer
      return self.class.allocate.__init(@jd + other, @df, @sf, @of, @start)
    when Rational
      return self + other.numerator if other.denominator == 1
      delta = other * 86400
    when Float
      raise FloatDomainError, other.to_s unless other.finite?
      neg = other < 0
      o = other.abs
      days = o.floor
      o -= days
      o *= 86400
      secs = o.floor
      o -= secs
      ns = (o * 1_000_000_000).round
      delta = days * 86400 + secs + Rational(ns, 1_000_000_000)
      delta = -delta if neg
    else
      raise TypeError, "expected numeric" unless other.is_a?(Numeric)
      r = other.to_r
      raise TypeError, "wrong argument type #{r.class} (expected Rational)" unless r.is_a?(Rational) || r.is_a?(Integer)
      return self + r
    end
    __plus_seconds(delta)
  end

  def __plus_seconds(delta)
    t = @df + @sf + delta
    dj = t.div(86400)
    rem = t - dj * 86400
    df = rem.floor
    self.class.allocate.__init(@jd + dj, df, (rem - df).to_r, @of, @start)
  end

  def -(other)
    return (__utc_secs - other.__utc_secs).to_r / 86400 if other.is_a?(Date)
    raise TypeError, "expected numeric" unless other.is_a?(Numeric)
    self + (-other)
  end

  def next_day(n = 1) = self + n
  def prev_day(n = 1) = self - n
  def succ = self + 1
  def next = self + 1

  # n months on; the day is clamped to the last that exists in that month
  # (in the reform's month, the last BEFORE the gap: 1583-10-14 << 12 is
  # 1582-10-04)
  def >>(n)
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    t = @year * 12 + (@month - 1) + n
    y = t.div(12)
    m = (t % 12).floor + 1
    d = @day
    jd = nil
    loop do
      jd = Date.__valid_civil_jd(y, m, d, @start)
      break if jd
      d -= 1
      raise Date::Error, "invalid date" if d < 1
    end
    self + (jd - @jd)
  end

  def <<(n)
    raise TypeError, "expected numeric" unless n.is_a?(Numeric)
    self >> -n
  end

  def next_month(n = 1) = self >> n
  def prev_month(n = 1) = self << n
  def next_year(n = 1) = self >> (n * 12)
  def prev_year(n = 1) = self << (n * 12)

  # --- comparing --------------------------------------------------------------
  # two dates by their instants (on UTC); a number by the astronomical
  # Julian Day it is compared with (Date.new(2001,2,3) <=> 2451943.5 is 0)
  def <=>(other)
    if other.is_a?(Date)
      a = __utc_day_secs
      b = other.__utc_day_secs
      return a <=> b if a != b
      return @sf <=> other.__sf
    end
    return ajd <=> other if other.is_a?(Numeric)
    return nil unless other.respond_to?(:coerce)
    a, b = other.coerce(self)
    a <=> b
  end

  def ==(other)
    return true if equal?(other)
    c = (self <=> other)
    c.nil? ? false : c == 0
  end

  # the same calendar DAY (the local one), whatever the time
  def ===(other)
    return @jd == other if other.is_a?(Numeric)
    return @jd == other.jd if other.is_a?(Date)
    return nil unless other.respond_to?(:coerce)
    a, b = other.coerce(self)
    a == b
  end

  def eql?(other) = other.is_a?(Date) && (self <=> other) == 0
  def hash = [__utc_day_secs, @sf].hash

  # --- iteration (d_lite_step) -------------------------------------------------
  # The direction is the step's sign asked of the step itself (`by <=> 0`),
  # so an object whose <=> answers nil is an ArgumentError, and one that
  # answers 2 is a step forward.
  def step(limit, by = 1)
    return to_enum(:step, limit, by) unless block_given?
    c = (by <=> 0)
    raise ArgumentError, "comparison of #{by.class} with 0 failed" if c.nil?
    c = c > 0 ? 1 : (c < 0 ? -1 : 0) unless c.is_a?(Integer)
    d = self
    if c < 0
      while (d <=> limit) >= 0
        yield d
        d += by
      end
    elsif c == 0
      loop { yield d }
    else
      while (d <=> limit) <= 0
        yield d
        d += by
      end
    end
    self
  end

  def upto(max)
    return to_enum(:upto, max) unless block_given?
    d = self
    while (d <=> max) <= 0
      yield d
      d += 1
    end
    self
  end

  def downto(min)
    return to_enum(:downto, min) unless block_given?
    d = self
    while (d <=> min) >= 0
      yield d
      d -= 1
    end
    self
  end

  # --- printing ---------------------------------------------------------------
  def __off_s
    a = @of.abs
    format("%s%02d:%02d", @of < 0 ? "-" : "+", a / 3600, a % 3600 / 60).force_encoding(Encoding::US_ASCII)
  end

  def __date_s = format("%s%04d-%02d-%02d", @year < 0 ? "-" : "", @year.abs, @month, @day)
  def to_s = __date_s.force_encoding(Encoding::US_ASCII)

  # the instant as ruby shows it: UTC day, seconds and nanoseconds, the
  # offset in seconds and the reform
  def inspect
    u = __utc_day_secs
    ns = @sf * 1_000_000_000
    ns = ns.to_i if ns.denominator == 1
    sts = @start.infinite? ? (@start < 0 ? "-Inf" : "Inf") : @start.to_i.to_s
    "#<#{self.class}: #{to_s} ((#{u.div(86400)}j,#{u % 86400}s,#{ns.inspect}n),#{@of < 0 ? '-' : '+'}#{@of.abs}s,#{sts}j)>".force_encoding(Encoding::US_ASCII)
  end

  # date_strftime's %z, which differs from Time's: "-" drops the hour's
  # padding (%-:::z is +9), and a width pads the hours
  def self.__strf_z(off, flags, width, colons)
    aoff = off.abs
    hl = aoff / 3600 < 10 ? 1 : 2
    hw = flags.include?("-") && hl == 1 ? 1 : 2
    extra = case colons
            when 0 then 3
            when 1 then 4
            when 2 then 7
            else aoff % 3600 == 0 ? 1 : (aoff % 60 == 0 ? 4 : 7)
            end
    prec = width || -1
    prec = prec <= extra + hw ? hw : prec - extra
    pad = nil
    flags.each_char { |c| pad = c if c == "_" || c == "0" }
    s = +""
    if pad == "_" && prec > hl
      s << " " * (prec - hl)
      prec = hl
    end
    s << (off < 0 ? "-" : "+")
    s << (aoff / 3600).to_s.rjust(prec, "0")
    r = aoff % 3600
    return s if colons == 3 && r == 0
    s << ":" if colons >= 1
    s << format("%02d", r / 60)
    r %= 60
    return s if colons == 3 && r == 0
    s << format(":%02d", r) if colons >= 2
    s
  end

  def __strf_fields
    [@year, @month, @day, yday, wday, @df / 3600, @df % 3600 / 60, @df % 60, @sf, @of, false, __off_s,
     __utc_secs - 210866803200, true]
  end

  # the one strftime engine (Time.__strf) with this date's fields; the
  # result is in the format's encoding (US-ASCII for the default formats)
  def __strftime(fmt)
    fmt = fmt.to_str unless fmt.is_a?(String)
    Date.__strf_range_check(fmt, @year)
    if fmt.include?("z")
      of = @of
      fmt = fmt.gsub(/%%|%[-_0^#]*\d*:*z/) do |m|
        next m if m == "%%"
        colons = m.count(":")
        next m if colons > 3
        flags = m[/\A%[-_0^#]*/][1..]
        w = m[1..][/\d+/]
        Date.__strf_z(of, flags, w && w.to_i, colons)
      end
    end
    Time.__strf(fmt, __strf_fields)
  end

  def strftime(fmt = "%F".dup.force_encoding(Encoding::US_ASCII)) = __strftime(fmt)

  def __ascii(fmt) = __strftime(fmt.dup.force_encoding(Encoding::US_ASCII))
  def asctime = __ascii("%a %b %e %H:%M:%S %Y")
  def ctime = __ascii("%a %b %e %H:%M:%S %Y")
  def iso8601 = __ascii("%Y-%m-%d")
  def xmlschema = __ascii("%Y-%m-%d")
  def rfc3339 = __ascii("%Y-%m-%dT%H:%M:%S%:z")
  def rfc2822 = __ascii("%a, %-d %b %Y %T %z")
  def rfc822 = __ascii("%a, %-d %b %Y %T %z")
  def httpdate
    u = @of == 0 ? self : self.class.allocate.__init(*__utc_parts, 0, @start)
    u.__ascii("%a, %d %b %Y %T GMT")
  end
  def __utc_parts
    u = __utc_day_secs
    [u.div(86400), u % 86400, @sf]
  end

  def jisx0301
    era, base = __jis_era
    return __ascii("%Y-%m-%d") unless era
    format("%s%02d.%02d.%02d", era, @year - base, @month, @day).force_encoding(Encoding::US_ASCII)
  end

  # --- conversions --------------------------------------------------------
  def to_date = self
  def to_datetime = DateTime.allocate.__init(@jd, 0, Rational(0, 1), 0, @start)
  # (Time's calendar is the Gregorian one)
  def to_time
    y, m, d = julian? ? Date.jd_to_gregorian(@jd) : [@year, @month, @day]
    Time.local(y, m, d)
  end

  # --- Marshal: [nth, jd, df, sf, of, sg], jd and df on UTC, sf in ns ------
  def marshal_dump
    j, df, sf = __utc_parts
    ns = sf * 1_000_000_000
    ns = ns.to_i if ns.denominator == 1
    [0, j, df, ns, @of, @start]
  end

  def __marshal_set(jd, df, sf, of, sg)
    u = jd * 86400 + df + of
    __init(u.div(86400), u % 86400, sf.to_r / 1_000_000_000, of, sg.is_a?(Numeric) ? sg.to_f : ITALY.to_f)
  end

  class Infinity < Numeric
    def <=>(other)
      case other
      when Infinity then d <=> other.d
      when Float::INFINITY then d <=> 1
      when -Float::INFINITY then d <=> -1
      when Numeric then d
      else
        begin
          l, r = other.coerce(self)
          return l <=> r
        rescue NoMethodError
        end
        nil
      end
    end
  end
end

class DateTime < Date
  class << self
    undef_method :today
  end

  # a time-of-day argument: numeric, and a fraction only in the last one given
  def self.__arg(v, name, unit, pos, n)
    Date.__num!(v, name)
    i, fr = Date.__trunc(v, unit)
    raise Date::Error, "invalid fraction" if fr != 0 && n > pos
    [i, fr]
  end

  def self.__build(jd, h, mi, s, of, sg, fr)
    t = Date.__valid_time(h, mi, s)
    raise Date::Error, "invalid date" if t.nil?
    h, mi, s = t
    if h == 24
      h = 0
      fr += 1
    end
    r = allocate.__init(jd, h * 3600 + mi * 60 + s, Rational(0, 1), of, sg)
    fr == 0 ? r : r + fr
  end

  # the clock arguments of every constructor, from the last to the first as
  # ruby checks them: [hour, minute, second, offset, start, fraction]
  def self.__clock(args, base, n)
    h, mi, s, of, sg = args[base, 5]
    sg = n > base + 4 ? Date.__sg(sg) : ITALY.to_f
    of = n > base + 3 ? Date.__val2off(of) : 0
    fr = 0
    s, f = n > base + 2 ? __arg(s, "second", 86400, 1 << 30, n) : [0, 0]
    fr = f if f != 0
    mi, f = n > base + 1 ? __arg(mi, "minute", 1440, base + 2, n) : [0, 0]
    fr = f if f != 0
    h, f = n > base ? __arg(h, "hour", 24, base + 1, n) : [0, 0]
    fr = f if f != 0
    [h, mi, s, of, sg, fr]
  end

  def self.new(*args)
    n = args.size
    raise ArgumentError, "wrong number of arguments (given #{n}, expected 0..8)" if n > 8
    h, mi, s, of, sg, fr = __clock(args, 3, n)
    y, m, d = args
    if n > 2
      d, f = __arg(d, "day", 1, 3, n)
      fr = f if f != 0
    else
      d = 1
    end
    m = n > 1 ? Date.__int(Date.__num!(m, "month")) : 1
    y = n > 0 ? Date.__int(Date.__num!(y, "year")) : -4712
    jd = Date.__valid_civil_jd(y, m, d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    __build(jd, h, mi, s, of, sg, fr)
  end

  def self.civil(*args) = new(*args)

  def self.jd(*args)
    n = args.size
    raise ArgumentError, "wrong number of arguments (given #{n}, expected 0..6)" if n > 6
    h, mi, s, of, sg, fr = __clock(args, 1, n)
    if n > 0
      jd, f = __arg(args[0], "jd", 1, 1, n)
      fr = f if f != 0
    else
      jd = 0
    end
    __build(jd, h, mi, s, of, sg, fr)
  end

  def self.ordinal(*args)
    n = args.size
    raise ArgumentError, "wrong number of arguments (given #{n}, expected 0..7)" if n > 7
    h, mi, s, of, sg, fr = __clock(args, 2, n)
    if n > 1
      d, f = __arg(args[1], "yday", 1, 2, n)
      fr = f if f != 0
    else
      d = 1
    end
    y = n > 0 ? Date.__int(Date.__num!(args[0], "year")) : -4712
    jd = Date.__valid_ordinal_jd(y, d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    __build(jd, h, mi, s, of, sg, fr)
  end

  def self.commercial(*args)
    n = args.size
    raise ArgumentError, "wrong number of arguments (given #{n}, expected 0..8)" if n > 8
    h, mi, s, of, sg, fr = __clock(args, 3, n)
    if n > 2
      d, f = __arg(args[2], "cwday", 1, 3, n)
      fr = f if f != 0
    else
      d = 1
    end
    w = n > 1 ? Date.__int(Date.__num!(args[1], "cweek")) : 1
    y = n > 0 ? Date.__int(Date.__num!(args[0], "year")) : -4712
    jd = Date.__valid_commercial_jd(y, w, d, sg)
    raise Date::Error, "invalid date" if jd.nil?
    __build(jd, h, mi, s, of, sg, fr)
  end

  # the local clock to the nanosecond, at the local offset
  def self.now(sg = ITALY)
    sg = Date.__sg(sg)
    t = Time.now
    s = t.sec
    s = 59 if s > 59
    allocate.__init(Date.gregorian_to_jd(t.year, t.mon, t.mday), t.hour * 3600 + t.min * 60 + s,
                    Rational(t.nsec, 1_000_000_000), t.utc_offset, sg)
  end

  # dt_new_by_frags: the date as Date's, then the clock, the fraction of the
  # second and the offset the fields carry (an offset beyond a day is
  # warned about and dropped)
  def self.__new_by_frags(h, sg)
    sg = Date.__sg(sg)
    raise Date::Error, "invalid date" if h.nil?
    h = h.dup
    if h[:jd].nil? && h[:yday].nil? && !h[:year].nil? && !h[:mon].nil? && !h[:mday].nil?
      jd = Date.__valid_civil_jd(Date.__int(h[:year]), Date.__int(h[:mon]), Date.__int(h[:mday]), sg)
      h[:hour] = 0 if h[:hour].nil?
      h[:min] = 0 if h[:min].nil?
      if h[:sec].nil?
        h[:sec] = 0
      elsif h[:sec] == 60
        h[:sec] = 59
      end
    else
      Date.__rewrite_frags(h)
      Date.__complete_frags(self, h)
      jd = Date.__valid_date_frags(h, sg)
    end
    raise Date::Error, "invalid date" if jd.nil?
    t = Date.__valid_time(Date.__int(h[:hour]), Date.__int(h[:min]), Date.__int(h[:sec]))
    raise Date::Error, "invalid date" if t.nil?
    sf = h[:sec_fraction].nil? ? Rational(0, 1) : h[:sec_fraction].to_r
    of = h[:offset].nil? ? 0 : Date.__int(h[:offset])
    if of < -86400 || of > 86400
      warn("warning: invalid offset is ignored") if $VERBOSE
      of = 0
    end
    r = allocate.__init(jd, t[0] * 3600 + t[1] * 60 + t[2], Rational(0, 1), of, sg)
    r = r.__plus_seconds(0) if t[0] == 24
    sf == 0 ? r : r.__plus_seconds(sf)
  end

  def self._strptime(str, fmt = "%FT%T%z") = Date._strptime(str, fmt)
  def self.strptime(str = "-4712-01-01T00:00:00+00:00", fmt = "%FT%T%z", sg = ITALY) = __new_by_frags(Date._strptime(str, fmt), sg)
  def self.parse(str = "-4712-01-01T00:00:00+00:00", comp = true, sg = ITALY, limit: 128) = __new_by_frags(Date._parse(str, comp, limit: limit), sg)
  def self.iso8601(str = "-4712-01-01T00:00:00+00:00", sg = ITALY, limit: 128) = __new_by_frags(Date._iso8601(str, limit: limit), sg)
  def self.rfc3339(str = "-4712-01-01T00:00:00+00:00", sg = ITALY, limit: 128) = __new_by_frags(Date._rfc3339(str, limit: limit), sg)
  def self.xmlschema(str = "-4712-01-01T00:00:00+00:00", sg = ITALY, limit: 128) = __new_by_frags(Date._xmlschema(str, limit: limit), sg)
  def self.rfc2822(str = "Mon, 1 Jan -4712 00:00:00 +0000", sg = ITALY, limit: 128) = __new_by_frags(Date._rfc2822(str, limit: limit), sg)
  def self.httpdate(str = "Mon, 01 Jan -4712 00:00:00 GMT", sg = ITALY, limit: 128) = __new_by_frags(Date._httpdate(str, limit: limit), sg)
  def self.jisx0301(str = "-4712-01-01T00:00:00+00:00", sg = ITALY, limit: 128) = __new_by_frags(Date._jisx0301(str, limit: limit), sg)
  class << self
    alias_method :rfc822, :rfc2822
  end

  # --- the clock ---------------------------------------------------------
  def hour = @df / 3600
  def minute = @df % 3600 / 60
  alias_method :min, :minute
  def second = @df % 60
  alias_method :sec, :second
  def sec_fraction = @sf
  alias_method :second_fraction, :sec_fraction
  def offset = @of.to_r / 86400
  def zone = __off_s
  def day_fraction = (@df + @sf).to_r / 86400

  # the same instant at another offset
  def new_offset(of = 0)
    o = Date.__val2off(of)
    u = __utc_day_secs + o
    self.class.allocate.__init(u.div(86400), u % 86400, @sf, o, @start)
  end

  # (the layers above defined these on DateTime; Date's are the ones now)
  def +(other) = super
  def -(other) = super
  def inspect = super
  def marshal_dump = super
  def __marshal_set(jd, df, sf, of, sg) = super

  def to_s
    (__date_s + format("T%02d:%02d:%02d", @df / 3600, @df % 3600 / 60, @df % 60) + __off_s).force_encoding(Encoding::US_ASCII)
  end

  def strftime(fmt = "%FT%T%:z".dup.force_encoding(Encoding::US_ASCII)) = __strftime(fmt)

  # T%H:%M:%S, n digits of the second's fraction, and the offset
  def __timediv(n)
    n = n.to_i
    __ascii(n > 0 ? "T%H:%M:%S.%#{n}N%:z" : "T%H:%M:%S%:z")
  end
  def iso8601(n = 0) = (__ascii("%Y-%m-%d") + __timediv(n)).force_encoding(Encoding::US_ASCII)
  def xmlschema(n = 0) = iso8601(n)
  def rfc3339(n = 0) = iso8601(n)
  def jisx0301(n = 0) = (super() + __timediv(n)).force_encoding(Encoding::US_ASCII)

  def to_date = Date.allocate.__init(@jd, 0, Rational(0, 1), 0, @start)
  def to_datetime = self
  def to_time
    y, m, d = julian? ? Date.jd_to_gregorian(@jd) : [@year, @month, @day]
    Time.new(y, m, d, @df / 3600, @df % 3600 / 60, @df % 60 + @sf, @of)
  end
end

class Date
  # date_core's zone table (zonetab.list), as "name=seconds" pairs
  def self.__zone_src
    [
      "ut=0;gmt=0;est=-18000;edt=-14400;cst=-21600;cdt=-18000;mst=-25200;mdt=-21600",
      "pst=-28800;pdt=-25200;a=3600;b=7200;c=10800;d=14400;e=18000;f=21600;g=25200;h=28800",
      "i=32400;k=36000;l=39600;m=43200;n=-3600;o=-7200;p=-10800;q=-14400;r=-18000;s=-21600",
      "t=-25200;u=-28800;v=-32400;w=-36000;x=-39600;y=-43200;z=0;utc=0;wet=0;at=-7200",
      "brst=-7200;ndt=-5400;art=-10800;adt=-10800;brt=-10800;clst=-10800;nst=-9000;ast=-14400",
      "clt=-14400;akdt=-28800;ydt=-28800;akst=-32400;hadt=-32400;hdt=-32400;yst=-32400",
      "ahst=-36000;cat=7200;hast=-36000;hst=-36000;nt=-39600;idlw=-43200;bst=3600;cet=3600",
      "fwt=3600;met=3600;mewt=3600;mez=3600;swt=3600;wat=3600;west=3600;cest=7200;eet=7200",
      "fst=7200;mest=7200;mesz=7200;sast=7200;sst=-39600;bt=10800;eat=10800;eest=10800",
      "msk=10800;msd=14400;zp4=14400;zp5=18000;ist=19800;zp6=21600;wast=7200;cct=23400",
      "sgt=28800;wadt=28800;jst=32400;kst=32400;east=-21600;gst=36000;eadt=39600;idle=43200",
      "nzst=43200;nzt=43200;nzdt=46800;afghanistan=16200;alaskan=-32400;arab=10800",
      "arabian=14400;arabic=10800;atlantic=-14400;aus central=34200;aus eastern=36000",
      "azores=-3600;canada central=-21600;cape verde=-3600;caucasus=14400",
      "cen. australia=34200;central america=-21600;central asia=21600;central europe=3600",
      "central european=3600;central pacific=39600;central=-21600;china=28800;dateline=-43200",
      "e. africa=10800;e. australia=36000;e. europe=7200;e. south america=-10800",
      "eastern=-18000;egypt=7200;ekaterinburg=18000;fiji=43200;fle=7200;greenland=-10800",
      "greenwich=0;gtb=7200;hawaiian=-36000;india=19800;iran=12600;jerusalem=7200;korea=32400",
      "mexico=-21600;mid-atlantic=-7200;mountain=-25200;myanmar=23400;n. central asia=21600",
      "nepal=20700;new zealand=43200;newfoundland=-12600;north asia east=28800",
      "north asia=25200;pacific sa=-14400;pacific=-28800;romance=3600;russian=10800",
      "sa eastern=-10800;sa pacific=-18000;sa western=-14400;samoa=-39600;se asia=25200",
      "malay peninsula=28800;south africa=7200;sri lanka=21600;taipei=28800;tasmania=36000",
      "tokyo=32400;tonga=46800;us eastern=-18000;us mountain=-25200;vladivostok=36000",
      "w. australia=28800;w. central africa=3600;w. europe=3600;west asia=18000",
      "west pacific=36000;yakutsk=32400;acdt=37800;acst=34200;act=-18000;acwst=31500",
      "aedt=39600;aest=36000;aft=16200;almt=21600;anast=43200;anat=43200;aoe=-43200",
      "aqtt=18000;awdt=32400;awst=28800;azost=0;azot=-3600;azst=18000;azt=14400;bnt=28800",
      "bot=-14400;btt=21600;cast=28800;chadt=49500;chast=45900;chost=32400;chot=28800",
      "chst=36000;chut=36000;cidst=-14400;cist=-18000;ckt=-36000;cot=-18000;cvt=-3600",
      "cxt=25200;davt=25200;ddut=36000;easst=-18000;ect=-18000;egst=0;egt=-3600;fet=10800",
      "fjst=46800;fjt=43200;fkst=-10800;fkt=-14400;fnt=-7200;galt=-21600;gamt=-32400",
      "get=14400;gft=-10800;gilt=43200;gyt=-14400;hkt=28800;hovst=28800;hovt=25200;ict=25200",
      "idt=10800;iot=21600;irdt=16200;irkst=32400;irkt=28800;irst=12600;kgt=21600;kost=39600",
      "krast=28800;krat=25200;kuyt=14400;lhdt=39600;lhst=37800;lint=50400;magst=43200",
      "magt=39600;mart=-30600;mawt=18000;mht=43200;mmt=23400;mut=14400;mvt=18000;myt=28800",
      "nct=39600;nfdt=43200;nft=39600;novst=25200;novt=25200;npt=20700;nrt=43200;nut=-39600",
      "omsst=25200;omst=21600;orat=18000;pet=-18000;petst=43200;pett=43200;pgt=36000",
      "phot=46800;pht=28800;pkt=18000;pmdt=-7200;pmst=-10800;pont=39600;pwt=32400;pyst=-10800",
      "qyzt=21600;ret=14400;rott=-10800;sakt=39600;samt=14400;sbt=39600;sct=14400;sret=39600",
      "srt=-10800;syot=10800;taht=-36000;tft=18000;tjt=18000;tkt=46800;tlt=32400;tmt=18000",
      "tost=50400;tot=46800;trt=10800;tvt=43200;ulast=32400;ulat=28800;uyst=-7200;uyt=-10800",
      "uzt=18000;vet=-14400;vlast=39600;vlat=36000;vost=21600;vut=39600;wakt=43200",
      "warst=-10800;wft=43200;wgst=-3600;wgt=-7200;wib=25200;wit=32400;wita=28800;wt=0",
      "yakst=36000;yakt=32400;yapt=36000;yekst=21600;yekt=18000",
    ]
  end
end

# ===========================================================================
# The readers are ruby's own, ported: Date::MereDateParse is date_parse.c
# (date__parse and the iso8601 / rfc3339 / xmlschema / rfc2822 / httpdate /
# jisx0301 readers, lib/date_parse_ext.rb) and Date::MereDateStrptime is
# date_strptime.c with date_core.c's frag completion (rt_rewrite_frags,
# rt_complete_frags, d_new_by_frags; lib/date_strptime_ext.rb). Both were
# checked against ruby 4.0.9 on every call test/date makes and on tens of
# thousands of generated inputs (tools/date_checks/). Every constructor
# below goes hash -> new_by_frags -> [jd, df, sf, of], as date_core does.
# ===========================================================================
class Date
  def self._parse(str, comp = true, limit: 128) = MereDateParse._parse(str, comp, limit: limit)
  def self._iso8601(str, limit: 128) = MereDateParse._iso8601(str, limit: limit)
  def self._rfc3339(str, limit: 128) = MereDateParse._rfc3339(str, limit: limit)
  def self._xmlschema(str, limit: 128) = MereDateParse._xmlschema(str, limit: limit)
  def self._rfc2822(str, limit: 128) = MereDateParse._rfc2822(str, limit: limit)
  def self._rfc822(str, limit: 128) = MereDateParse._rfc822(str, limit: limit)
  def self._httpdate(str, limit: 128) = MereDateParse._httpdate(str, limit: limit)
  def self._jisx0301(str, limit: 128) = MereDateParse._jisx0301(str, limit: limit)
  def self._strptime(str, fmt = "%F") = MereDateStrptime._strptime(str, fmt)

  # the object a [jd, df, sf, of] quadruple (UTC day, seconds, nanoseconds,
  # offset seconds) names, of this class
  def self.__from_quad(q, start)
    raise Date::Error, "invalid date" if q.nil?
    jd, df, sf, of = q
    sg = __sg(start.nil? ? ITALY : start)
    return allocate.__init(jd, 0, Rational(0, 1), 0, sg) unless self <= DateTime
    # (the quadruple is UTC; the model keeps the local day and seconds)
    local = jd * 86400 + df + of
    allocate.__init(local.div(86400), local % 86400, Rational(sf, 1_000_000_000), of, sg)
  end

  def self.__new_by_hash(hash, start)
    # (an offset past a day is dropped, with ruby's verbose-mode warning)
    if $VERBOSE && hash.is_a?(Hash) && hash[:offset].is_a?(Numeric) && self <= DateTime &&
       (hash[:offset] < -86400 || hash[:offset] > 86400)
      warn("invalid offset is ignored", uplevel: 2)
    end
    __from_quad(MereDateStrptime.new_by_frags(self <= DateTime ? :datetime : :date, hash, start.nil? ? ITALY : start), start)
  end

  def self.parse(str = "-4712-01-01", comp = true, start = ITALY, limit: 128)
    __new_by_hash(_parse(str, comp, limit: limit), start)
  end
  def self.strptime(str = "-4712-01-01", fmt = "%F", start = ITALY)
    __new_by_hash(_strptime(str, fmt), start)
  end
  def self.iso8601(str = "-4712-01-01", start = ITALY, limit: 128) = __new_by_hash(_iso8601(str, limit: limit), start)
  def self.rfc3339(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128) = __new_by_hash(_rfc3339(str, limit: limit), start)
  def self.xmlschema(str = "-4712-01-01", start = ITALY, limit: 128) = __new_by_hash(_xmlschema(str, limit: limit), start)
  def self.rfc2822(str = "Mon, 1 Jan -4712 00:00:00 +0000", start = ITALY, limit: 128) = __new_by_hash(_rfc2822(str, limit: limit), start)
  def self.httpdate(str = "Mon, 01 Jan -4712 00:00:00 GMT", start = ITALY, limit: 128) = __new_by_hash(_httpdate(str, limit: limit), start)
  def self.jisx0301(str = "-4712-01-01", start = ITALY, limit: 128) = __new_by_hash(_jisx0301(str, limit: limit), start)
  class << self
    alias rfc822 rfc2822
  end
end

class DateTime < Date
  def self._strptime(str, fmt = "%FT%T%z") = MereDateStrptime._strptime(str, fmt)
  def self.parse(str = "-4712-01-01T00:00:00+00:00", comp = true, start = ITALY, limit: 128)
    __new_by_hash(_parse(str, comp, limit: limit), start)
  end
  def self.strptime(str = "-4712-01-01T00:00:00+00:00", fmt = "%FT%T%z", start = ITALY)
    __new_by_hash(_strptime(str, fmt), start)
  end
  def self.iso8601(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128) = __new_by_hash(_iso8601(str, limit: limit), start)
  def self.rfc3339(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128) = __new_by_hash(_rfc3339(str, limit: limit), start)
  def self.xmlschema(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128) = __new_by_hash(_xmlschema(str, limit: limit), start)
  def self.rfc2822(str = "Mon, 1 Jan -4712 00:00:00 +0000", start = ITALY, limit: 128) = __new_by_hash(_rfc2822(str, limit: limit), start)
  def self.httpdate(str = "Mon, 01 Jan -4712 00:00:00 GMT", start = ITALY, limit: 128) = __new_by_hash(_httpdate(str, limit: limit), start)
  def self.jisx0301(str = "-4712-01-01T00:00:00+00:00", start = ITALY, limit: 128) = __new_by_hash(_jisx0301(str, limit: limit), start)
  class << self
    alias rfc822 rfc2822
  end
end
