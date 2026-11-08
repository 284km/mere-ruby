# frozen_string_literal: false
#
# MereDateParse -- a pure-Ruby port of CRuby's ext/date/date_parse.c
# (date__parse and its sub-parsers, date_zone_to_diff with the zone table
# from zonetab.list, and the format readers date__iso8601, date__rfc3339,
# date__xmlschema, date__rfc2822, date__httpdate, date__jisx0301), plus the
# argument handling of date_core.c (check_limit, the ASCII-compatible check,
# the default comp).
#
# The order of the sub-parsers and the regexps follow the C source (non
# TIGHT_PARSER build) one for one. The only change to a regexp is that
# parse_us's possessive `\s*+` is written `\s*`: whitespace given back can
# only be taken again by the `\s*` that follows, so the matches are the same.
#
# As in C, each sub-parser that matches replaces the matched text of the
# working string with a single space (subx), and the character-class test
# (check_class) is made again on the current string before each step.
module MereDateParse

  ZONE_TABLE = {
    "ut" => 0, "gmt" => 0, "est" => -18000, "edt" => -14400,
    "cst" => -21600, "cdt" => -18000, "mst" => -25200, "mdt" => -21600,
    "pst" => -28800, "pdt" => -25200, "a" => 3600, "b" => 7200,
    "c" => 10800, "d" => 14400, "e" => 18000, "f" => 21600,
    "g" => 25200, "h" => 28800, "i" => 32400, "k" => 36000,
    "l" => 39600, "m" => 43200, "n" => -3600, "o" => -7200,
    "p" => -10800, "q" => -14400, "r" => -18000, "s" => -21600,
    "t" => -25200, "u" => -28800, "v" => -32400, "w" => -36000,
    "x" => -39600, "y" => -43200, "z" => 0, "utc" => 0,
    "wet" => 0, "at" => -7200, "brst" => -7200, "ndt" => -5400,
    "art" => -10800, "adt" => -10800, "brt" => -10800, "clst" => -10800,
    "nst" => -9000, "ast" => -14400, "clt" => -14400, "akdt" => -28800,
    "ydt" => -28800, "akst" => -32400, "hadt" => -32400, "hdt" => -32400,
    "yst" => -32400, "ahst" => -36000, "cat" => 7200, "hast" => -36000,
    "hst" => -36000, "nt" => -39600, "idlw" => -43200, "bst" => 3600,
    "cet" => 3600, "fwt" => 3600, "met" => 3600, "mewt" => 3600,
    "mez" => 3600, "swt" => 3600, "wat" => 3600, "west" => 3600,
    "cest" => 7200, "eet" => 7200, "fst" => 7200, "mest" => 7200,
    "mesz" => 7200, "sast" => 7200, "sst" => -39600, "bt" => 10800,
    "eat" => 10800, "eest" => 10800, "msk" => 10800, "msd" => 14400,
    "zp4" => 14400, "zp5" => 18000, "ist" => 19800, "zp6" => 21600,
    "wast" => 7200, "cct" => 23400, "sgt" => 28800, "wadt" => 28800,
    "jst" => 32400, "kst" => 32400, "east" => -21600, "gst" => 36000,
    "eadt" => 39600, "idle" => 43200, "nzst" => 43200, "nzt" => 43200,
    "nzdt" => 46800, "afghanistan" => 16200, "alaskan" => -32400, "arab" => 10800,
    "arabian" => 14400, "arabic" => 10800, "atlantic" => -14400, "aus central" => 34200,
    "aus eastern" => 36000, "azores" => -3600, "canada central" => -21600, "cape verde" => -3600,
    "caucasus" => 14400, "cen. australia" => 34200, "central america" => -21600, "central asia" => 21600,
    "central europe" => 3600, "central european" => 3600, "central pacific" => 39600, "central" => -21600,
    "china" => 28800, "dateline" => -43200, "e. africa" => 10800, "e. australia" => 36000,
    "e. europe" => 7200, "e. south america" => -10800, "eastern" => -18000, "egypt" => 7200,
    "ekaterinburg" => 18000, "fiji" => 43200, "fle" => 7200, "greenland" => -10800,
    "greenwich" => 0, "gtb" => 7200, "hawaiian" => -36000, "india" => 19800,
    "iran" => 12600, "jerusalem" => 7200, "korea" => 32400, "mexico" => -21600,
    "mid-atlantic" => -7200, "mountain" => -25200, "myanmar" => 23400, "n. central asia" => 21600,
    "nepal" => 20700, "new zealand" => 43200, "newfoundland" => -12600, "north asia east" => 28800,
    "north asia" => 25200, "pacific sa" => -14400, "pacific" => -28800, "romance" => 3600,
    "russian" => 10800, "sa eastern" => -10800, "sa pacific" => -18000, "sa western" => -14400,
    "samoa" => -39600, "se asia" => 25200, "malay peninsula" => 28800, "south africa" => 7200,
    "sri lanka" => 21600, "taipei" => 28800, "tasmania" => 36000, "tokyo" => 32400,
    "tonga" => 46800, "us eastern" => -18000, "us mountain" => -25200, "vladivostok" => 36000,
    "w. australia" => 28800, "w. central africa" => 3600, "w. europe" => 3600, "west asia" => 18000,
    "west pacific" => 36000, "yakutsk" => 32400, "acdt" => 37800, "acst" => 34200,
    "act" => -18000, "acwst" => 31500, "aedt" => 39600, "aest" => 36000,
    "aft" => 16200, "almt" => 21600, "anast" => 43200, "anat" => 43200,
    "aoe" => -43200, "aqtt" => 18000, "awdt" => 32400, "awst" => 28800,
    "azost" => 0, "azot" => -3600, "azst" => 18000, "azt" => 14400,
    "bnt" => 28800, "bot" => -14400, "btt" => 21600, "cast" => 28800,
    "chadt" => 49500, "chast" => 45900, "chost" => 32400, "chot" => 28800,
    "chst" => 36000, "chut" => 36000, "cidst" => -14400, "cist" => -18000,
    "ckt" => -36000, "cot" => -18000, "cvt" => -3600, "cxt" => 25200,
    "davt" => 25200, "ddut" => 36000, "easst" => -18000, "ect" => -18000,
    "egst" => 0, "egt" => -3600, "fet" => 10800, "fjst" => 46800,
    "fjt" => 43200, "fkst" => -10800, "fkt" => -14400, "fnt" => -7200,
    "galt" => -21600, "gamt" => -32400, "get" => 14400, "gft" => -10800,
    "gilt" => 43200, "gyt" => -14400, "hkt" => 28800, "hovst" => 28800,
    "hovt" => 25200, "ict" => 25200, "idt" => 10800, "iot" => 21600,
    "irdt" => 16200, "irkst" => 32400, "irkt" => 28800, "irst" => 12600,
    "kgt" => 21600, "kost" => 39600, "krast" => 28800, "krat" => 25200,
    "kuyt" => 14400, "lhdt" => 39600, "lhst" => 37800, "lint" => 50400,
    "magst" => 43200, "magt" => 39600, "mart" => -30600, "mawt" => 18000,
    "mht" => 43200, "mmt" => 23400, "mut" => 14400, "mvt" => 18000,
    "myt" => 28800, "nct" => 39600, "nfdt" => 43200, "nft" => 39600,
    "novst" => 25200, "novt" => 25200, "npt" => 20700, "nrt" => 43200,
    "nut" => -39600, "omsst" => 25200, "omst" => 21600, "orat" => 18000,
    "pet" => -18000, "petst" => 43200, "pett" => 43200, "pgt" => 36000,
    "phot" => 46800, "pht" => 28800, "pkt" => 18000, "pmdt" => -7200,
    "pmst" => -10800, "pont" => 39600, "pwt" => 32400, "pyst" => -10800,
    "qyzt" => 21600, "ret" => 14400, "rott" => -10800, "sakt" => 39600,
    "samt" => 14400, "sbt" => 39600, "sct" => 14400, "sret" => 39600,
    "srt" => -10800, "syot" => 10800, "taht" => -36000, "tft" => 18000,
    "tjt" => 18000, "tkt" => 46800, "tlt" => 32400, "tmt" => 18000,
    "tost" => 50400, "tot" => 46800, "trt" => 10800, "tvt" => 43200,
    "ulast" => 32400, "ulat" => 28800, "uyst" => -7200, "uyt" => -10800,
    "uzt" => 18000, "vet" => -14400, "vlast" => 39600, "vlat" => 36000,
    "vost" => 21600, "vut" => 39600, "wakt" => 43200, "warst" => -10800,
    "wft" => 43200, "wgst" => -3600, "wgt" => -7200, "wib" => 25200,
    "wit" => 32400, "wita" => 28800, "wt" => 0, "yakst" => 36000,
    "yakt" => 32400, "yapt" => 36000, "yekst" => 21600, "yekt" => 18000,
  }.freeze

  ABBR_DAYS = %w[sun mon tue wed thu fri sat].freeze
  ABBR_MONTHS = %w[jan feb mar apr may jun jul aug sep oct nov dec].freeze

  # ---------------------------------------------------------------- helpers

  def self.__isdigit(c)
    !c.nil? && c >= "0" && c <= "9" && c.length == 1
  end

  def self.__issign(c)
    c == "-" || c == "+"
  end

  # C isspace in the "C" locale
  def self.__isspace(c)
    c == " " || c == "\t" || c == "\n" || c == "\v" || c == "\f" || c == "\r"
  end

  # (one search, not a character at a time: a 100,000-digit year --
  #  test__parse_too_long_year -- is under three seconds that way)
  def self.__digit_span(s, i)
    j = s.index(/[^0-9]/, i) || s.length
    j < i ? 0 : j - i
  end

  # rb_str_to_inum(s, 10, 0) on the digit runs the regexps capture
  def self.__str2num(s)
    s.to_i
  end

  def self.__day_num(s)
    k = s[0, 3].downcase
    i = 0
    while i < 7
      break if ABBR_DAYS[i] == k
      i += 1
    end
    i
  end

  def self.__mon_num(s)
    k = s[0, 3].downcase
    i = 0
    while i < 12
      break if ABBR_MONTHS[i] == k
      i += 1
    end
    i + 1
  end

  def self.__sec_fraction(f)
    Rational(f.to_i, 10**f.bytesize)
  end

  def self.__comp_year69(y)
    y >= 69 ? y + 1900 : y + 2000
  end

  def self.__comp_year50(y)
    y >= 50 ? y + 1900 : y + 2000
  end

  # s3e(): file y/m/d strings (any of which may be nil) as year/mon/mday,
  # guessing which is which the way C does
  def self.__s3e(hash, y, m, d, bc)
    c = nil
    m = m.to_s unless m.nil? || m.is_a?(String)

    if !y.nil? && !m.nil? && d.nil?
      oy = y
      om = m
      od = d
      y = od
      m = oy
      d = om
    end

    if y.nil?
      if !d.nil? && d.bytesize > 2
        y = d
        d = nil
      end
      if !d.nil? && d.bytesize > 0 && d[0] == "'"
        y = d
        d = nil
      end
    end

    unless y.nil?
      n = y.length
      i = 0
      i += 1 while i < n && !__issign(y[i]) && !__isdigit(y[i])
      if i < n
        bp = i
        i += 1 if __issign(y[i])
        l = __digit_span(y, i)
        ep = i + l
        if ep < n
          oy = y
          y = d
          d = oy[bp, ep - bp]
        end
      end
    end

    unless m.nil?
      if m[0] == "'" || m.bytesize > 2
        # us -> be
        oy = y
        om = m
        od = d
        y = om
        m = od
        d = oy
      end
    end

    unless d.nil?
      if d[0] == "'" || d.bytesize > 2
        oy = y
        od = d
        y = od
        d = oy
      end
    end

    unless y.nil?
      n = y.length
      i = 0
      i += 1 while i < n && !__issign(y[i]) && !__isdigit(y[i])
      if i < n
        bp = i
        sign = false
        if __issign(y[i])
          i += 1
          sign = true
        end
        c = false if sign
        l = __digit_span(y, i)
        ep = i + l
        c = false if l > 2
        hash[:year] = y[bp, ep - bp].to_i
      end
    end

    hash[:_bc] = true if bc

    unless m.nil?
      n = m.length
      i = 0
      i += 1 while i < n && !__isdigit(m[i])
      if i < n
        l = __digit_span(m, i)
        hash[:mon] = m[i, l].to_i
      end
    end

    unless d.nil?
      n = d.length
      i = 0
      i += 1 while i < n && !__isdigit(d[i])
      if i < n
        l = __digit_span(d, i)
        hash[:mday] = d[i, l].to_i
      end
    end

    hash[:_comp] = c unless c.nil?
  end

  # subx(): on a match, replace the matched text of str with " " and file
  # the fields; true when the regexp matched (whatever the callback did)
  def self.__subx(str, re, hash)
    m = re.match(str)
    return false if m.nil?
    be = m.begin(0)
    en = m.end(0)
    str[be, en - be] = " "
    yield m, hash
    true
  end

  # -------------------------------------------------------- zone -> offset

  MAX_WORD_LENGTH = 17

  def self.__bisspace(b)
    !b.nil? && (b == 32 || (b >= 9 && b <= 13))
  end

  def self.__bdigit(b)
    !b.nil? && b >= 48 && b <= 57
  end

  def self.__bdowncase(s)
    s.tr("A-Z", "a-z")
  end

  # str_end_with_word(): the length of " word" (with the white space
  # before it) ending s[0, l], or 0
  def self.__str_end_with_word(s, l, w)
    n = w.bytesize
    return 0 if l <= n || !__bisspace(s.getbyte(l - n - 1))
    return 0 if __bdowncase(s.byteslice(l - n, n)) != w
    loop do
      n += 1
      break unless l > n && __bisspace(s.getbyte(l - n - 1))
    end
    n
  end

  def self.__shrunk_size(s, l)
    i = 0
    ni = 0
    sp = false
    while i < l
      if !__bisspace(s.getbyte(i))
        ni += 1 if sp
        sp = false
        ni += 1
      else
        sp = true
      end
      i += 1
    end
    ni < l ? ni : 0
  end

  def self.__shrink_space(s, l)
    d = "".b
    i = 0
    sp = false
    while i < l
      b = s.getbyte(i)
      if !__bisspace(b)
        d << " " if sp
        sp = false
        d << b.chr
      else
        sp = true
      end
      i += 1
    end
    d
  end

  # ruby_scan_digits(s + i, len, 10): [value, digits scanned];
  # len < 0 means no limit
  def self.__scan_digits(s, i, len)
    return [0, 0] if len == 0
    v = 0
    j = i
    while (len < 0 || j - i < len) && __bdigit(s.getbyte(j))
      v = v * 10 + (s.getbyte(j) - 48)
      j += 1
    end
    [v, j - i]
  end

  ULONG_MAX = 18446744073709551615
  LONG_MAX = 9223372036854775807

  # ruby_strtoul(s + i, &p, 10): [value as a C long, index of p]
  def self.__strtoul(s, i)
    start = i
    i += 1 while __bisspace(s.getbyte(i))
    c = s.getbyte(i)
    sign = 0
    if c == 43
      sign = 1
      i += 1
    elsif c == 45
      sign = -1
      i += 1
    end
    found = start
    if s.getbyte(i) == 48
      found = i + 1
      i += 1
    end
    v, len = __scan_digits(s, i, -1)
    found = i + len if len > 0
    if v > ULONG_MAX
      v = ULONG_MAX
    elsif sign < 0
      v = (-v) & ULONG_MAX
    end
    # unsigned long -> long
    v -= ULONG_MAX + 1 if v > LONG_MAX
    [v, found]
  end

  # date_zone_to_diff(): the offset in seconds a zone string names, or nil
  def self.zone_to_diff(str)
    s = str.b
    l = s.bytesize
    dst = false

    w = __str_end_with_word(s, l, "time")
    if w > 0
      wtime = w
      l -= w
      if (w = __str_end_with_word(s, l, "standard")) > 0
        l -= w
      elsif (w = __str_end_with_word(s, l, "daylight")) > 0
        l -= w
        dst = true
      else
        l += wtime
      end
    elsif (w = __str_end_with_word(s, l, "dst")) > 0
      l -= w
      dst = true
    end

    zn = s
    sl = __shrunk_size(s, l)
    if sl <= 0
      sl = l
    elsif sl <= MAX_WORD_LENGTH
      zn = __shrink_space(s, l)
      sl = zn.bytesize
    end
    if sl > 0 && sl <= MAX_WORD_LENGTH
      z = ZONE_TABLE[__bdowncase(zn.byteslice(0, sl))]
      unless z.nil?
        z += 3600 if dst
        return z
      end
    end

    p0 = 0
    if l > 3
      head = __bdowncase(s.byteslice(0, 3))
      if head == "gmt" || head == "utc"
        p0 += 3
        l -= 3
      end
    end
    c = s.getbyte(p0)
    return nil unless c == 43 || c == 45
    sign = c == 45
    p0 += 1
    l -= 1
    hour = 0
    min = 0
    sec = 0

    hour, p = __strtoul(s, p0)
    if s.getbyte(p) == 58 # ':'
      return nil if hour < 0 || hour > 23
      p0 = p + 1
      min, p = __strtoul(s, p0)
      return nil if min < 0 || min > 59
      if s.getbyte(p) == 58
        p0 = p + 1
        sec, p = __strtoul(s, p0)
        return nil if sec < 0 || sec > 59
      end
    elsif s.getbyte(p) == 44 || s.getbyte(p) == 46 # ',' '.'
      # fractional hour
      return nil if hour < 0 || hour > 23
      p += 1
      n = (p0 + l) - p
      n = 7 if n < 0 || n > 7
      sec, n = __scan_digits(s, p, n)
      p += n
      if p < p0 + l
        b = s.getbyte(p)
        sec += 1 if !b.nil? && b >= (53 + (sec.odd? ? 0 : 1)) && b <= 57
      end
      sec *= 36
      if sign
        hour = -hour
        sec = -sec
      end
      if n <= 2
        sec *= 10 if n == 1
        return sec + hour * 3600
      end
      offset = Rational(sec, 10**(n - 2)) + hour * 3600
      offset = offset.numerator if offset.denominator == 1
      return offset
    elsif l > 2
      hour, = __scan_digits(s, p0, 2 - l % 2)
      min, = __scan_digits(s, p0 + 2 - l % 2, 2) if l >= 3
      sec, = __scan_digits(s, p0 + 4 - l % 2, 2) if l >= 5
    end
    sec += min * 60 + hour * 3600
    sec = -sec if sign
    sec
  end

  # ------------------------------------------------------------- _parse

  RE_GSUB = /[^-+',.\/:@[:alnum:]\[\]]+/

  RE_DAY = /\b(sun|mon|tue|wed|thu|fri|sat)[^-\/\d\s]*/i

  RE_TIME = /((?<!\d)\d+\s*(?:(?::\s*\d+(?:\s*:\s*\d+(?:[,.]\d*)?)?|h(?:\s*\d+m?(?:\s*\d+s?)?)?)(?:\s*[ap](?:m\b|\.m\.))?|[ap](?:m\b|\.m\.)))(?:\s*((?:gmt|utc?)?[-+]\d+(?:[,.:]\d+(?::\d+)?)?|(?-i:[[:alpha:].\s]+)(?:standard|daylight)\stime\b|(?-i:[[:alpha:]]+)(?:\sdst)?\b))?/i

  RE_TIME2 = /\A(\d+)h?(?:\s*:?\s*(\d+)m?(?:\s*:?\s*(\d+)(?:[,.](\d+))?s?)?)?(?:\s*([ap])(?:m\b|\.m\.))?/i

  RE_EU = /('?(?<!\d)\d+)[^-\d\s]*\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[^-\d\s']*(?:\s*(?:\b(c(?:e|\.e\.)|b(?:ce|\.c\.e\.)|a(?:d|\.d\.)|b(?:c|\.c\.))(?!(?<!\.)[a-z]))?\s*('?-?\d+(?:(?:st|nd|rd|th)\b)?))?/i

  RE_US = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[^-\d\s']*\s*('?\d+)[^-\d\s']*(?:\s*,?\s*(c(?:e|\.e\.)|b(?:ce|\.c\.e\.)|a(?:d|\.d\.)|b(?:c|\.c\.))?\s*('?-?\d+))?/i

  RE_ISO = /('?[-+]?(?<!\d)\d+)-(\d+)-('?-?\d+)/

  RE_ISO21 = /\b(\d{2}|\d{4})?-?w(\d{2})(?:-?(\d))?\b/i
  RE_ISO22 = /-w-(\d)\b/i
  RE_ISO23 = /--(\d{2})?-(\d{2})\b/
  RE_ISO24 = /--(\d{2})(\d{2})?\b/
  RE_ISO25_0 = /[,.](\d{2}|\d{4})-\d{3}\b/
  RE_ISO25 = /\b(\d{2}|\d{4})-(\d{3})\b/
  RE_ISO26_0 = /\d-\d{3}\b/
  RE_ISO26 = /\b-(\d{3})\b/

  RE_JIS = /\b([mtshr])(\d+)\.(\d+)\.(\d+)/i

  RE_VMS11 = /('?-?(?<!\d)\d+)-(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[^-\/.]*-('?-?\d+)/i
  RE_VMS12 = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[^-\/.]*-('?-?\d+)(?:-('?-?\d+))?/i

  RE_SLA = /('?-?(?<!\d)\d+)\/\s*('?\d+)(?:\D\s*('?-?\d+))?/i
  RE_DOT = /('?-?(?<!\d)\d+)\.\s*('?\d+)\.\s*('?-?\d+)/i

  RE_YEAR = /'(\d+)\b/
  RE_MON = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\S*/i
  RE_MDAY = /((?<!\d)\d+)(st|nd|rd|th)\b/i

  RE_DDD = /([-+]?)((?<!\d)\d{2,14})(?:\s*t?\s*(\d{2,6})?(?:[,.](\d*))?)?(?:\s*(z\b|[-+]\d{1,4}\b|\[[-+]?\d[^\]]*\]))?/i

  RE_BC = /\b(bc\b|bce\b|b\.c\.|b\.c\.e\.)/i
  RE_FRAG = /\A\s*(\d{1,2})\s*\z/i

  def self.__parse_day(str, hash)
    __subx(str, RE_DAY, hash) do |m, h|
      h[:wday] = __day_num(m[1])
    end
  end

  def self.__parse_time(str, hash)
    __subx(str, RE_TIME, hash) do |m, h|
      s1 = m[1]
      s2 = m[2]
      h[:zone] = s2 unless s2.nil?
      m2 = RE_TIME2.match(s1)
      __parse_time2(m2, h) unless m2.nil?
    end
  end

  def self.__parse_time2(m, hash)
    h = __str2num(m[1])
    min = m[2]
    min = __str2num(min) unless min.nil?
    s = m[3]
    s = __str2num(s) unless s.nil?
    f = m[4]
    f = Rational(__str2num(f), 10**f.bytesize) unless f.nil?
    p = m[5]
    unless p.nil?
      raise RangeError, "integer #{h} too big to convert to 'int'" if h > 2147483647
      ih = h % 12
      ih += 12 if p[0] == "P" || p[0] == "p"
      h = ih
    end
    hash[:hour] = h
    hash[:min] = min unless min.nil?
    hash[:sec] = s unless s.nil?
    hash[:sec_fraction] = f unless f.nil?
  end

  def self.__bc_p(b)
    !b.nil? && (b[0] == "B" || b[0] == "b")
  end

  def self.__parse_eu(str, hash)
    __subx(str, RE_EU, hash) do |m, h|
      __s3e(h, m[4], __mon_num(m[2]), m[1], __bc_p(m[3]))
    end
  end

  def self.__parse_us(str, hash)
    __subx(str, RE_US, hash) do |m, h|
      __s3e(h, m[4], __mon_num(m[1]), m[2], __bc_p(m[3]))
    end
  end

  def self.__parse_iso(str, hash)
    __subx(str, RE_ISO, hash) do |m, h|
      __s3e(h, m[1], m[2], m[3], false)
    end
  end

  def self.__parse_iso21(str, hash)
    __subx(str, RE_ISO21, hash) do |m, h|
      h[:cwyear] = __str2num(m[1]) unless m[1].nil?
      h[:cweek] = __str2num(m[2])
      h[:cwday] = __str2num(m[3]) unless m[3].nil?
    end
  end

  def self.__parse_iso22(str, hash)
    __subx(str, RE_ISO22, hash) do |m, h|
      h[:cwday] = __str2num(m[1])
    end
  end

  def self.__parse_iso23(str, hash)
    __subx(str, RE_ISO23, hash) do |m, h|
      h[:mon] = __str2num(m[1]) unless m[1].nil?
      h[:mday] = __str2num(m[2])
    end
  end

  def self.__parse_iso24(str, hash)
    __subx(str, RE_ISO24, hash) do |m, h|
      h[:mon] = __str2num(m[1])
      h[:mday] = __str2num(m[2]) unless m[2].nil?
    end
  end

  def self.__parse_iso25(str, hash)
    return false unless RE_ISO25_0.match(str).nil?
    __subx(str, RE_ISO25, hash) do |m, h|
      h[:year] = __str2num(m[1])
      h[:yday] = __str2num(m[2])
    end
  end

  def self.__parse_iso26(str, hash)
    return false unless RE_ISO26_0.match(str).nil?
    __subx(str, RE_ISO26, hash) do |m, h|
      h[:yday] = __str2num(m[1])
    end
  end

  def self.__parse_iso2(str, hash)
    return true if __parse_iso21(str, hash)
    return true if __parse_iso22(str, hash)
    return true if __parse_iso23(str, hash)
    return true if __parse_iso24(str, hash)
    return true if __parse_iso25(str, hash)
    return true if __parse_iso26(str, hash)
    false
  end

  def self.__gengo(c)
    case c
    when "M", "m" then 1867
    when "T", "t" then 1911
    when "S", "s" then 1925
    when "H", "h" then 1988
    when "R", "r" then 2018
    else 0
    end
  end

  def self.__parse_jis(str, hash)
    __subx(str, RE_JIS, hash) do |m, h|
      ep = __gengo(m[1][0])
      h[:year] = __str2num(m[2]) + ep
      h[:mon] = __str2num(m[3])
      h[:mday] = __str2num(m[4])
    end
  end

  def self.__parse_vms11(str, hash)
    __subx(str, RE_VMS11, hash) do |m, h|
      __s3e(h, m[3], __mon_num(m[2]), m[1], false)
    end
  end

  def self.__parse_vms12(str, hash)
    __subx(str, RE_VMS12, hash) do |m, h|
      __s3e(h, m[3], __mon_num(m[1]), m[2], false)
    end
  end

  def self.__parse_vms(str, hash)
    return true if __parse_vms11(str, hash)
    return true if __parse_vms12(str, hash)
    false
  end

  def self.__parse_sla(str, hash)
    __subx(str, RE_SLA, hash) do |m, h|
      __s3e(h, m[1], m[2], m[3], false)
    end
  end

  def self.__parse_dot(str, hash)
    __subx(str, RE_DOT, hash) do |m, h|
      __s3e(h, m[1], m[2], m[3], false)
    end
  end

  def self.__parse_year(str, hash)
    __subx(str, RE_YEAR, hash) do |m, h|
      h[:year] = __str2num(m[1])
    end
  end

  def self.__parse_mon(str, hash)
    __subx(str, RE_MON, hash) do |m, h|
      h[:mon] = __mon_num(m[1])
    end
  end

  def self.__parse_mday(str, hash)
    __subx(str, RE_MDAY, hash) do |m, h|
      h[:mday] = __str2num(m[1])
    end
  end

  def self.__n2i(s, f, w)
    s[f, w].to_i
  end

  def self.__parse_ddd(str, hash)
    __subx(str, RE_DDD, hash) do |m, h|
      __parse_ddd_cb(m, h)
    end
  end

  def self.__parse_ddd_cb(m, hash)
    s1 = m[1]
    s2 = m[2]
    s3 = m[3]
    s4 = m[4]
    s5 = m[5]
    neg = !s1.nil? && s1[0] == "-"
    l2 = s2.length
    tm = s3.nil? && !s4.nil?

    case l2
    when 2
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
      else
        hash[:mday] = __n2i(s2, 0, 2)
      end
    when 4
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 4, 2)
      else
        hash[:mon] = __n2i(s2, 0, 2)
        hash[:mday] = __n2i(s2, 2, 2)
      end
    when 6
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 4, 2)
        hash[:hour] = __n2i(s2, l2 - 6, 2)
      else
        y = __n2i(s2, 0, 2)
        y = -y if neg
        hash[:year] = y
        hash[:mon] = __n2i(s2, 2, 2)
        hash[:mday] = __n2i(s2, 4, 2)
      end
    when 8, 10, 12, 14
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 4, 2)
        hash[:hour] = __n2i(s2, l2 - 6, 2)
        hash[:mday] = __n2i(s2, l2 - 8, 2)
        hash[:mon] = __n2i(s2, l2 - 10, 2) if l2 >= 10
        if l2 == 12
          y = __n2i(s2, l2 - 12, 2)
          y = -y if neg
          hash[:year] = y
        end
        if l2 == 14
          y = __n2i(s2, l2 - 14, 4)
          y = -y if neg
          hash[:year] = y
          hash[:_comp] = false
        end
      else
        y = __n2i(s2, 0, 4)
        y = -y if neg
        hash[:year] = y
        hash[:mon] = __n2i(s2, 4, 2)
        hash[:mday] = __n2i(s2, 6, 2)
        hash[:hour] = __n2i(s2, 8, 2) if l2 >= 10
        hash[:min] = __n2i(s2, 10, 2) if l2 >= 12
        hash[:sec] = __n2i(s2, 12, 2) if l2 >= 14
        hash[:_comp] = false
      end
    when 3
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 3, 1)
      else
        hash[:yday] = __n2i(s2, 0, 3)
      end
    when 5
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 4, 2)
        hash[:hour] = __n2i(s2, l2 - 5, 1)
      else
        y = __n2i(s2, 0, 2)
        y = -y if neg
        hash[:year] = y
        hash[:yday] = __n2i(s2, 2, 3)
      end
    when 7
      if tm
        hash[:sec] = __n2i(s2, l2 - 2, 2)
        hash[:min] = __n2i(s2, l2 - 4, 2)
        hash[:hour] = __n2i(s2, l2 - 6, 2)
        hash[:mday] = __n2i(s2, l2 - 7, 1)
      else
        y = __n2i(s2, 0, 4)
        y = -y if neg
        hash[:year] = y
        hash[:yday] = __n2i(s2, 4, 3)
      end
    end

    unless s3.nil?
      l3 = s3.length
      if !s4.nil?
        if l3 == 2 || l3 == 4 || l3 == 6
          hash[:sec] = __n2i(s3, l3 - 2, 2)
          hash[:min] = __n2i(s3, l3 - 4, 2) if l3 >= 4
          hash[:hour] = __n2i(s3, l3 - 6, 2) if l3 >= 6
        end
      else
        if l3 == 2 || l3 == 4 || l3 == 6
          hash[:hour] = __n2i(s3, 0, 2)
          hash[:min] = __n2i(s3, 2, 2) if l3 >= 4
          hash[:sec] = __n2i(s3, 4, 2) if l3 >= 6
        end
      end
    end

    unless s4.nil?
      hash[:sec_fraction] = Rational(__str2num(s4), 10**s4.bytesize)
    end

    unless s5.nil?
      hash[:zone] = s5
      if s5[0] == "["
        b5 = s5.b
        l5 = b5.bytesize - 2
        k = b5.index(":", 1)
        k = nil if !k.nil? && k >= 1 + l5
        if k
          zone = s5.byteslice(k + 1, l5 - k)
          s5 = s5.byteslice(1, k)
        else
          zone = s5.byteslice(1, l5)
          s5 = __bdigit(b5.getbyte(1)) ? "+" + zone : zone
        end
        hash[:zone] = zone
        hash[:offset] = zone_to_diff(s5)
      end
    end
    true
  end

  def self.__parse_bc(str, hash)
    __subx(str, RE_BC, hash) do |_m, h|
      h[:_bc] = true
    end
  end

  def self.__parse_frag(str, hash)
    __subx(str, RE_FRAG, hash) do |m, h|
      s = m[1]
      if !h[:hour].nil? && h[:mday].nil?
        n = __str2num(s)
        h[:mday] = n if n >= 1 && n <= 31
      end
      if !h[:mday].nil? && h[:hour].nil?
        n = __str2num(s)
        h[:hour] = n if n >= 0 && n <= 24
      end
    end
  end

  HAVE_ALPHA = 1
  HAVE_DIGIT = 2
  HAVE_DASH = 4
  HAVE_DOT = 8
  HAVE_SLASH = 16

  # (five searches over the bytes rather than a block call per byte: the
  #  class test runs before every sub-parser, on the whole string)
  def self.__check_class(s)
    b = s.b
    flags = 0
    flags |= HAVE_ALPHA if b.match?(/[A-Za-z]/n)
    flags |= HAVE_DIGIT if b.match?(/[0-9]/n)
    flags |= HAVE_DASH if b.include?("-")
    flags |= HAVE_DOT if b.include?(".")
    flags |= HAVE_SLASH if b.include?("/")
    flags
  end

  def self.__have(str, x)
    (__check_class(str) & x) == x
  end

  # date__parse()
  def self.__date_parse(str, comp)
    str = str.dup
    str.gsub!(RE_GSUB, " ")

    hash = {}
    hash[:_comp] = comp

    __parse_day(str, hash) if __have(str, HAVE_ALPHA)
    __parse_time(str, hash) if __have(str, HAVE_DIGIT)

    __parse_rest(str, hash)

    __parse_bc(str, hash) if __have(str, HAVE_ALPHA)
    __parse_frag(str, hash) if __have(str, HAVE_DIGIT)

    if hash.delete(:_bc)
      y = hash[:cwyear]
      hash[:cwyear] = -y + 1 unless y.nil?
      y = hash[:year]
      hash[:year] = -y + 1 unless y.nil?
    end

    if hash.delete(:_comp)
      y = hash[:cwyear]
      if !y.nil? && y >= 0 && y <= 99
        hash[:cwyear] = y >= 69 ? y + 1900 : y + 2000
      end
      y = hash[:year]
      if !y.nil? && y >= 0 && y <= 99
        hash[:year] = y >= 69 ? y + 1900 : y + 2000
      end
    end

    zone = hash[:zone]
    hash[:offset] = zone_to_diff(zone) if !zone.nil? && hash[:offset].nil?

    hash
  end

  # the sub-parsers between parse_time and the `ok:` label; the first one
  # that matches ends the run
  def self.__parse_rest(str, hash)
    if __have(str, HAVE_ALPHA | HAVE_DIGIT)
      return if __parse_eu(str, hash)
      return if __parse_us(str, hash)
    end
    return if __have(str, HAVE_DIGIT | HAVE_DASH) && __parse_iso(str, hash)
    return if __have(str, HAVE_DIGIT | HAVE_DOT) && __parse_jis(str, hash)
    return if __have(str, HAVE_ALPHA | HAVE_DIGIT | HAVE_DASH) && __parse_vms(str, hash)
    return if __have(str, HAVE_DIGIT | HAVE_SLASH) && __parse_sla(str, hash)
    return if __have(str, HAVE_DIGIT | HAVE_DOT) && __parse_dot(str, hash)
    return if __have(str, HAVE_DIGIT) && __parse_iso2(str, hash)
    return if __have(str, HAVE_DIGIT) && __parse_year(str, hash)
    return if __have(str, HAVE_ALPHA) && __parse_mon(str, hash)
    return if __have(str, HAVE_DIGIT) && __parse_mday(str, hash)
    return if __have(str, HAVE_DIGIT) && __parse_ddd(str, hash)
    nil
  end

  # -------------------------------------------------------- _iso8601

  RE_ISO8601_EXT_DATETIME = /\A\s*(?:([-+]?\d{2,}|-)-(\d{2})?(?:-(\d{2}))?|([-+]?\d{2,})?-(\d{3})|(\d{4}|\d{2})?-w(\d{2})-(\d)|-w-(\d))(?:t(\d{2}):(\d{2})(?::(\d{2})(?:[,.](\d+))?)?(z|[-+]\d{2}(?::?\d{2})?)?)?\s*\z/i

  RE_ISO8601_BAS_DATETIME = /\A\s*(?:([-+]?(?:\d{4}|\d{2})|--)(\d{2}|-)(\d{2})|([-+]?(?:\d{4}|\d{2}))(\d{3})|-(\d{3})|(\d{4}|\d{2})w(\d{2})(\d)|-w(\d{2})(\d)|-w-(\d))(?:t?(\d{2})(\d{2})(?:(\d{2})(?:[,.](\d+))?)?(z|[-+]\d{2}(?:\d{2})?)?)?\s*\z/i

  RE_ISO8601_EXT_TIME = /\A\s*(\d{2}):(\d{2})(?::(\d{2})(?:[,.](\d+))?(z|[-+]\d{2}(:?\d{2})?)?)?\s*\z/i

  RE_ISO8601_BAS_TIME = /\A\s*(\d{2})(\d{2})(?:(\d{2})(?:[,.](\d+))?(z|[-+]\d{2}(\d{2})?)?)?\s*\z/i

  def self.__iso8601_ext_datetime_cb(m, hash)
    s = m
    if !s[1].nil?
      hash[:mday] = __str2num(s[3]) unless s[3].nil?
      if s[1] != "-"
        y = __str2num(s[1])
        y = __comp_year69(y) if s[1].bytesize < 4
        hash[:year] = y
      end
      if s[2].nil?
        return if s[1] != "-"
      else
        hash[:mon] = __str2num(s[2])
      end
    elsif !s[5].nil?
      hash[:yday] = __str2num(s[5])
      unless s[4].nil?
        y = __str2num(s[4])
        y = __comp_year69(y) if s[4].bytesize < 4
        hash[:year] = y
      end
    elsif !s[8].nil?
      hash[:cweek] = __str2num(s[7])
      hash[:cwday] = __str2num(s[8])
      unless s[6].nil?
        y = __str2num(s[6])
        y = __comp_year69(y) if s[6].bytesize < 4
        hash[:cwyear] = y
      end
    elsif !s[9].nil?
      hash[:cwday] = __str2num(s[9])
    end
    unless s[10].nil?
      hash[:hour] = __str2num(s[10])
      hash[:min] = __str2num(s[11])
      hash[:sec] = __str2num(s[12]) unless s[12].nil?
    end
    hash[:sec_fraction] = __sec_fraction(s[13]) unless s[13].nil?
    unless s[14].nil?
      hash[:zone] = s[14]
      hash[:offset] = zone_to_diff(s[14])
    end
  end

  def self.__iso8601_bas_datetime_cb(m, hash)
    s = m
    if !s[3].nil?
      hash[:mday] = __str2num(s[3])
      if s[1] != "--"
        y = __str2num(s[1])
        y = __comp_year69(y) if s[1].bytesize < 4
        hash[:year] = y
      end
      if s[2][0] == "-"
        return if s[1] != "--"
      else
        hash[:mon] = __str2num(s[2])
      end
    elsif !s[5].nil?
      hash[:yday] = __str2num(s[5])
      y = __str2num(s[4])
      y = __comp_year69(y) if s[4].bytesize < 4
      hash[:year] = y
    elsif !s[6].nil?
      hash[:yday] = __str2num(s[6])
    elsif !s[9].nil?
      hash[:cweek] = __str2num(s[8])
      hash[:cwday] = __str2num(s[9])
      y = __str2num(s[7])
      y = __comp_year69(y) if s[7].bytesize < 4
      hash[:cwyear] = y
    elsif !s[11].nil?
      hash[:cweek] = __str2num(s[10])
      hash[:cwday] = __str2num(s[11])
    elsif !s[12].nil?
      hash[:cwday] = __str2num(s[12])
    end
    unless s[13].nil?
      hash[:hour] = __str2num(s[13])
      hash[:min] = __str2num(s[14])
      hash[:sec] = __str2num(s[15]) unless s[15].nil?
    end
    hash[:sec_fraction] = __sec_fraction(s[16]) unless s[16].nil?
    unless s[17].nil?
      hash[:zone] = s[17]
      hash[:offset] = zone_to_diff(s[17])
    end
  end

  # iso8601_ext_time_cb (also iso8601_bas_time_cb, and the shape of
  # xmlschema_time_cb)
  def self.__time_cb(s, hash)
    hash[:hour] = __str2num(s[1])
    hash[:min] = __str2num(s[2])
    hash[:sec] = __str2num(s[3]) unless s[3].nil?
    hash[:sec_fraction] = __sec_fraction(s[4]) unless s[4].nil?
    unless s[5].nil?
      hash[:zone] = s[5]
      hash[:offset] = zone_to_diff(s[5])
    end
  end

  def self.__date_iso8601(str)
    hash = {}
    return hash if str.nil?
    if (m = RE_ISO8601_EXT_DATETIME.match(str))
      __iso8601_ext_datetime_cb(m, hash)
    elsif (m = RE_ISO8601_BAS_DATETIME.match(str))
      __iso8601_bas_datetime_cb(m, hash)
    elsif (m = RE_ISO8601_EXT_TIME.match(str))
      __time_cb(m, hash)
    elsif (m = RE_ISO8601_BAS_TIME.match(str))
      __time_cb(m, hash)
    end
    hash
  end

  # -------------------------------------------------------- _rfc3339

  RE_RFC3339 = /\A\s*(-?\d{4})-(\d{2})-(\d{2})(?:t|\s)(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(z|[-+]\d{2}:\d{2})\s*\z/i

  def self.__date_rfc3339(str)
    hash = {}
    return hash if str.nil?
    s = RE_RFC3339.match(str)
    unless s.nil?
      hash[:year] = __str2num(s[1])
      hash[:mon] = __str2num(s[2])
      hash[:mday] = __str2num(s[3])
      hash[:hour] = __str2num(s[4])
      hash[:min] = __str2num(s[5])
      hash[:sec] = __str2num(s[6])
      hash[:zone] = s[8]
      hash[:offset] = zone_to_diff(s[8])
      hash[:sec_fraction] = __sec_fraction(s[7]) unless s[7].nil?
    end
    hash
  end

  # -------------------------------------------------------- _xmlschema

  RE_XMLSCHEMA_DATETIME = /\A\s*(-?\d{4,})(?:-(\d{2})(?:-(\d{2}))?)?(?:t(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?)?(z|[-+]\d{2}:\d{2})?\s*\z/i
  RE_XMLSCHEMA_TIME = /\A\s*(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(z|[-+]\d{2}:\d{2})?\s*\z/i
  RE_XMLSCHEMA_TRUNC = /\A\s*(?:--(\d{2})(?:-(\d{2}))?|---(\d{2}))(z|[-+]\d{2}:\d{2})?\s*\z/i

  def self.__date_xmlschema(str)
    hash = {}
    return hash if str.nil?
    if (s = RE_XMLSCHEMA_DATETIME.match(str))
      hash[:year] = __str2num(s[1])
      hash[:mon] = __str2num(s[2]) unless s[2].nil?
      hash[:mday] = __str2num(s[3]) unless s[3].nil?
      hash[:hour] = __str2num(s[4]) unless s[4].nil?
      hash[:min] = __str2num(s[5]) unless s[5].nil?
      hash[:sec] = __str2num(s[6]) unless s[6].nil?
      hash[:sec_fraction] = __sec_fraction(s[7]) unless s[7].nil?
      unless s[8].nil?
        hash[:zone] = s[8]
        hash[:offset] = zone_to_diff(s[8])
      end
    elsif (s = RE_XMLSCHEMA_TIME.match(str))
      __time_cb(s, hash)
    elsif (s = RE_XMLSCHEMA_TRUNC.match(str))
      hash[:mon] = __str2num(s[1]) unless s[1].nil?
      hash[:mday] = __str2num(s[2]) unless s[2].nil?
      hash[:mday] = __str2num(s[3]) unless s[3].nil?
      unless s[4].nil?
        hash[:zone] = s[4]
        hash[:offset] = zone_to_diff(s[4])
      end
    end
    hash
  end

  # -------------------------------------------------------- _rfc2822

  RE_RFC2822 = /\A\s*(?:(sun|mon|tue|wed|thu|fri|sat)\s*,\s+)?(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(-?\d{2,})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([-+]\d{4}|ut|gmt|e[sd]t|c[sd]t|m[sd]t|p[sd]t|[a-ik-z])\s*\z/i

  def self.__date_rfc2822(str)
    hash = {}
    return hash if str.nil?
    s = RE_RFC2822.match(str)
    unless s.nil?
      hash[:wday] = __day_num(s[1]) unless s[1].nil?
      hash[:mday] = __str2num(s[2])
      hash[:mon] = __mon_num(s[3])
      y = __str2num(s[4])
      y = __comp_year50(y) if s[4].bytesize < 4
      hash[:year] = y
      hash[:hour] = __str2num(s[5])
      hash[:min] = __str2num(s[6])
      hash[:sec] = __str2num(s[7]) unless s[7].nil?
      hash[:zone] = s[8]
      hash[:offset] = zone_to_diff(s[8])
    end
    hash
  end

  # -------------------------------------------------------- _httpdate

  RE_HTTPDATE_TYPE1 = /\A\s*(sun|mon|tue|wed|thu|fri|sat)\s*,\s+(\d{2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(-?\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+(gmt)\s*\z/i
  RE_HTTPDATE_TYPE2 = /\A\s*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s*,\s+(\d{2})\s*-\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s*-\s*(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+(gmt)\s*\z/i
  RE_HTTPDATE_TYPE3 = /\A\s*(sun|mon|tue|wed|thu|fri|sat)\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})\s*\z/i

  def self.__date_httpdate(str)
    hash = {}
    return hash if str.nil?
    if (s = RE_HTTPDATE_TYPE1.match(str))
      hash[:wday] = __day_num(s[1])
      hash[:mday] = __str2num(s[2])
      hash[:mon] = __mon_num(s[3])
      hash[:year] = __str2num(s[4])
      hash[:hour] = __str2num(s[5])
      hash[:min] = __str2num(s[6])
      hash[:sec] = __str2num(s[7])
      hash[:zone] = s[8]
      hash[:offset] = 0
    elsif (s = RE_HTTPDATE_TYPE2.match(str))
      hash[:wday] = __day_num(s[1])
      hash[:mday] = __str2num(s[2])
      hash[:mon] = __mon_num(s[3])
      y = __str2num(s[4])
      y = __comp_year69(y) if y >= 0 && y <= 99
      hash[:year] = y
      hash[:hour] = __str2num(s[5])
      hash[:min] = __str2num(s[6])
      hash[:sec] = __str2num(s[7])
      hash[:zone] = s[8]
      hash[:offset] = 0
    elsif (s = RE_HTTPDATE_TYPE3.match(str))
      hash[:wday] = __day_num(s[1])
      hash[:mon] = __mon_num(s[2])
      hash[:mday] = __str2num(s[3])
      hash[:hour] = __str2num(s[4])
      hash[:min] = __str2num(s[5])
      hash[:sec] = __str2num(s[6])
      hash[:year] = __str2num(s[7])
    end
    hash
  end

  # -------------------------------------------------------- _jisx0301

  RE_JISX0301 = /\A\s*([mtshr])?(\d{2})\.(\d{2})\.(\d{2})(?:t(?:(\d{2}):(\d{2})(?::(\d{2})(?:[,.](\d*))?)?(z|[-+]\d{2}(?::?\d{2})?)?)?)?\s*\z/i

  def self.__date_jisx0301(str)
    hash = {}
    return hash if str.nil?
    s = RE_JISX0301.match(str)
    return __date_iso8601(str) if s.nil?
    ep = __gengo(s[1].nil? ? "H" : s[1][0])
    hash[:year] = __str2num(s[2]) + ep
    hash[:mon] = __str2num(s[3])
    hash[:mday] = __str2num(s[4])
    unless s[5].nil?
      hash[:hour] = __str2num(s[5])
      hash[:min] = __str2num(s[6]) unless s[6].nil?
      hash[:sec] = __str2num(s[7]) unless s[7].nil?
    end
    hash[:sec_fraction] = __sec_fraction(s[8]) unless s[8].nil?
    unless s[9].nil?
      hash[:zone] = s[9]
      hash[:offset] = zone_to_diff(s[9])
    end
    hash
  end

  # -------------------------------------------- the date_core.c entries

  # StringValue()
  def self.__string_value(str)
    return str if str.is_a?(String)
    if str.respond_to?(:to_str)
      s = str.to_str
      return s if s.is_a?(String)
      raise TypeError, "can't convert #{str.class} to String (#{str.class}#to_str gives #{s.class})"
    end
    name = if str.nil? then "nil"
           elsif str == true then "true"
           elsif str == false then "false"
           else str.class.to_s
           end
    raise TypeError, "no implicit conversion of #{name} into String"
  end

  # check_limit(): limit nil means no limit
  def self.__check_limit(str, limit)
    str = __string_value(str)
    if !limit.nil?
      lim = limit.to_int
      slen = str.bytesize
      raise ArgumentError, "string length (#{slen}) exceeds the limit #{lim}" if slen > lim
    end
    str
  end

  def self._parse(str, comp = true, limit: 128)
    str = __check_limit(str, limit)
    unless str.encoding.ascii_compatible?
      raise ArgumentError, "string should have ASCII compatible encoding"
    end
    __date_parse(str, comp)
  end

  def self._iso8601(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_iso8601(str)
  end

  def self._rfc3339(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_rfc3339(str)
  end

  def self._xmlschema(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_xmlschema(str)
  end

  def self._rfc2822(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_rfc2822(str)
  end

  def self._rfc822(str, limit: 128)
    _rfc2822(str, limit: limit)
  end

  def self._httpdate(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_httpdate(str)
  end

  def self._jisx0301(str, limit: 128)
    str = __check_limit(str, limit) unless str.nil?
    __date_jisx0301(str)
  end
end
