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
    obj = super(y, m, d)
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
    obj = __new_fields(y, m, d, h, mi, sfr == 0 ? si : si + sfr, off)
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
        t = (ajd + Rational(1, 2) + vof) * 86400
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
