# frozen_string_literal: true
#
# MereDateStrptime -- CRuby 4.0.9's Date._strptime (ext/date/date_strptime.c,
# date__strptime_internal + date__strptime), the zone-offset reader it calls
# (date_parse.c: date_zone_to_diff, with zonetab.list), and the way
# Date.strptime / DateTime.strptime turn the resulting hash into a date
# (date_core.c: rt_rewrite_frags, rt_complete_frags, rt__valid_date_frags_p,
# d_new_by_frags, dt_new_by_frags), ported to plain Ruby.
#
# The scanner works on bytes (String#b / #getbyte / #byteslice), as the C
# does; the only regexp is the zone pattern of %Z / %z.
#
#   MereDateStrptime._strptime(str, fmt = '%F')  -> Hash or nil
#   MereDateStrptime.rewrite_frags(hash)          -> hash (in place)
#   MereDateStrptime.complete_frags(klass, hash[, today_jd]) -> hash (in place)
#   MereDateStrptime.valid_date_frags_p(hash, sg) -> jd or nil
#   MereDateStrptime.new_by_frags(klass, hash, sg = ITALY)
#       -> [jd, df, sf, of] (jd/df as UTC, sf in ns, of in s) or nil where
#          date_core raises Date::Error ("invalid date")
#   MereDateStrptime.date_strptime(str, fmt, sg)     / datetime_strptime(...)
#       -> the same quadruple for Date.strptime / DateTime.strptime
module MereDateStrptime
  ITALY = 2299161
  GREGORIAN = -Float::INFINITY
  JULIAN = Float::INFINITY
  UNIX_EPOCH_IN_CJD = 2440588
  DAY_IN_SECONDS = 86400
  CM_PERIOD = 213447717        # (0xfffffff / 71149239) * 71149239
  CM_PERIOD_JCY = 584388       # CM_PERIOD / 1461 * 4
  CM_PERIOD_GCY = 584400       # CM_PERIOD / 146097 * 400
  REFORM_BEGIN_JD = 2298874
  REFORM_END_JD = 2426355
  FIXNUM_MAX = 4611686018427387903
  FIXNUM_MIN = -4611686018427387904

  DAY_NAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
  MONTH_NAMES = %w[January February March April May June July August
                   September October November December].freeze

  NUM_PAT_CHARS = "CDdeFGgHIjkLlMmNQRrSsTUuVvWwXxYy"
  E_CHARS = "cCxXyY"
  O_CHARS = "deHImMSuUVwWy"

  FMT_C = "%a %b %e %H:%M:%S %Y"
  FMT_D = "%m/%d/%y"
  FMT_F = "%Y-%m-%d"
  FMT_R = "%H:%M"
  FMT_RR = "%I:%M:%S %p"
  FMT_T = "%H:%M:%S"
  FMT_V = "%e-%b-%Y"
  FMT_SP = " "
  FMT_PLUS = "%a %b %e %H:%M:%S %Z %Y"

  # \A( (?:gmt|utc?)?[-+]\d+(?:[,.:]\d+(?::\d+)?)?
  #   | (?-i:[[:alpha:].\s]+)(?:standard|daylight)\s+time\b
  #   | (?-i:[[:alpha:]]+)(?:\s+dst)?\b )         -- ignore case, ASCII only
  ZONE_PAT = /\A((?:gmt|utc?)?[-+][0-9]+(?:[,.:][0-9]+(?::[0-9]+)?)?|[a-z.\t\n\v\f\r ]+(?:standard|daylight)[\t\n\v\f\r ]+time\b|[a-z]+(?:[\t\n\v\f\r ]+dst)?\b)/i

  MAX_WORD_LENGTH = 17
  ZONES = {
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

  # ---------------------------------------------------------------- bytes

  def self.__at(s, i, len)
    i < len ? s.getbyte(i) : 0
  end

  def self.__space?(b)
    b == 32 || (b >= 9 && b <= 13)
  end

  def self.__digit?(b)
    !b.nil? && b >= 48 && b <= 57
  end

  def self.__lower(b)
    b >= 65 && b <= 90 ? b + 32 : b
  end

  # strncasecmp(name, &s[i], len) == 0, with s long enough
  def self.__case_eq?(s, i, name, len)
    k = 0
    while k < len
      return false if __lower(s.getbyte(i + k)) != __lower(name.getbyte(k))
      k += 1
    end
    true
  end

  def self.__fail(h)
    h[:_fail] = true
    0
  end

  # read_digits: at most `width` digits (nil = no limit) -> [count, value] or nil
  def self.__read_digits(s, si, slen, width)
    l = 0
    while si + l < slen && __digit?(s.getbyte(si + l))
      l += 1
      break if l == width
    end
    return nil if l == 0
    [l, s.byteslice(si, l).to_i]
  end

  def self.__num_pattern_p(f, i, flen)
    b = __at(f, i, flen)
    return true if __digit?(b)
    if b == 37 # %
      i += 1
      b = __at(f, i, flen)
      if b == 69 || b == 79 # E O
        i += 1
        b = __at(f, i, flen)
      end
      return true if b != 0 && b < 128 && (NUM_PAT_CHARS.include?(b.chr) || __digit?(b))
    end
    false
  end

  # ------------------------------------------------- date__strptime_internal

  # Scans s[si...slen] against f[0...flen]; returns the bytes consumed, or 0
  # with h[:_fail] set.
  def self.__internal(s, si, slen, f, flen, h)
    si0 = si
    fi = 0
    while fi < flen
      fc = f.getbyte(fi)
      if __space?(fc)
        si += 1 while si < slen && __space?(s.getbyte(si))
        fi += 1
        fi += 1 while fi < flen && __space?(f.getbyte(fi))
        next
      end

      return __fail(h) if si >= slen

      if fc != 37 # ordinal character
        return __fail(h) if s.getbyte(si) != fc
        si += 1
        fi += 1
        next
      end

      # '%' -- the "again" loop of the C: E/O modifiers and %:z %::z %:::z
      fi += 1
      c = __at(f, fi, flen)
      ordinal = false
      while true
        if c == 69 || c == 79 # E O
          n = __at(f, fi + 1, flen)
          if n != 0 && n < 128 && (c == 69 ? E_CHARS : O_CHARS).include?(n.chr)
            fi += 1
            c = n
            next
          end
          fi -= 1
          ordinal = true
        elsif c == 58 # ':'
          i = 1
          i += 1 while i < 3 && fi + i < flen && f.getbyte(fi + i) == 58
          return __fail(h) unless __at(f, fi + i, flen) == 122 # z
          fi += i
          c = 122
        end
        break
      end
      if ordinal
        return __fail(h) if s.getbyte(si) != f.getbyte(fi)
        si += 1
        fi += 1
        next
      end

      sub = nil
      case c.chr
      when "A", "a"
        hit = false
        i = 0
        while i < 7
          name = DAY_NAMES[i]
          l = name.bytesize
          if (slen - si >= l && __case_eq?(s, si, name, l)) ||
             (slen - si >= 3 && __case_eq?(s, si, name, l = 3))
            si += l
            h[:wday] = i
            hit = true
            break
          end
          i += 1
        end
        return __fail(h) unless hit
      when "B", "b", "h"
        hit = false
        i = 0
        while i < 12
          name = MONTH_NAMES[i]
          l = name.bytesize
          if (slen - si >= l && __case_eq?(s, si, name, l)) ||
             (slen - si >= 3 && __case_eq?(s, si, name, l = 3))
            si += l
            h[:mon] = i + 1
            hit = true
            break
          end
          i += 1
        end
        return __fail(h) unless hit
      when "C"
        r = __read_digits(s, si, slen, __num_pattern_p(f, fi + 1, flen) ? 2 : nil)
        return __fail(h) if r.nil?
        si += r[0]
        h[:_cent] = r[1]
      when "c"
        sub = FMT_C
      when "D", "x"
        sub = FMT_D
      when "d", "e"
        if s.getbyte(si) == 32
          si += 1
          r = __read_digits(s, si, slen, 1)
        else
          r = __read_digits(s, si, slen, 2)
        end
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 31
        h[:mday] = r[1]
      when "F"
        sub = FMT_F
      when "G"
        r = __read_digits(s, si, slen, __num_pattern_p(f, fi + 1, flen) ? 4 : nil)
        return __fail(h) if r.nil?
        si += r[0]
        h[:cwyear] = r[1]
      when "g"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        return __fail(h) if n < 0 || n > 99
        h[:cwyear] = n
        h[:_cent] = (n >= 69 ? 19 : 20) if h[:_cent].nil?
      when "H", "k"
        if s.getbyte(si) == 32
          si += 1
          r = __read_digits(s, si, slen, 1)
        else
          r = __read_digits(s, si, slen, 2)
        end
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 0 || r[1] > 24
        h[:hour] = r[1]
      when "I", "l"
        if s.getbyte(si) == 32
          si += 1
          r = __read_digits(s, si, slen, 1)
        else
          r = __read_digits(s, si, slen, 2)
        end
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 12
        h[:hour] = r[1]
      when "j"
        r = __read_digits(s, si, slen, 3)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 366
        h[:yday] = r[1]
      when "L", "N"
        sign = 1
        b = s.getbyte(si)
        if b == 45 || b == 43
          sign = -1 if b == 45
          si += 1
        end
        osi = si
        w = __num_pattern_p(f, fi + 1, flen) ? (c == 76 ? 3 : 9) : nil
        r = __read_digits(s, si, slen, w)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        n = -n if sign == -1
        h[:sec_fraction] = Rational(n, 10**(si - osi))
      when "M"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 0 || r[1] > 59
        h[:min] = r[1]
      when "m"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 12
        h[:mon] = r[1]
      when "n", "t"
        sub = FMT_SP
      when "P", "p"
        return __fail(h) if slen - si < 2
        b = s.getbyte(si)
        hour = (b == 80 || b == 112) ? 12 : 0
        return __fail(h) if hour == 0 && !(b == 65 || b == 97)
        b = s.getbyte(si + 1)
        if b == 46 # '.'
          return __fail(h) if slen - si < 4 || s.getbyte(si + 3) != 46
          si += 2
          b = s.getbyte(si)
        end
        return __fail(h) unless b == 77 || b == 109
        si += 2
        h[:_merid] = hour
      when "Q"
        sign = 1
        if s.getbyte(si) == 45
          sign = -1
          si += 1
        end
        r = __read_digits(s, si, slen, nil)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        n = -n if sign == -1
        h[:seconds] = Rational(n, 1000)
      when "R"
        sub = FMT_R
      when "r"
        sub = FMT_RR
      when "S"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 0 || r[1] > 60
        h[:sec] = r[1]
      when "s"
        sign = 1
        if s.getbyte(si) == 45
          sign = -1
          si += 1
        end
        r = __read_digits(s, si, slen, nil)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        n = -n if sign == -1
        h[:seconds] = n
      when "T", "X"
        sub = FMT_T
      when "U", "W"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 0 || r[1] > 53
        h[c == 85 ? :wnum0 : :wnum1] = r[1]
      when "u"
        r = __read_digits(s, si, slen, 1)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 7
        h[:cwday] = r[1]
      when "V"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 1 || r[1] > 53
        h[:cweek] = r[1]
      when "v"
        sub = FMT_V
      when "w"
        r = __read_digits(s, si, slen, 1)
        return __fail(h) if r.nil?
        si += r[0]
        return __fail(h) if r[1] < 0 || r[1] > 6
        h[:wday] = r[1]
      when "Y"
        sign = 1
        b = s.getbyte(si)
        if b == 45 || b == 43
          sign = -1 if b == 45
          si += 1
        end
        r = __read_digits(s, si, slen, __num_pattern_p(f, fi + 1, flen) ? 4 : nil)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        n = -n if sign == -1
        h[:year] = n
      when "y"
        r = __read_digits(s, si, slen, 2)
        return __fail(h) if r.nil?
        si += r[0]
        n = r[1]
        return __fail(h) if n < 0 || n > 99
        h[:year] = n
        h[:_cent] = (n >= 69 ? 19 : 20) if h[:_cent].nil?
      when "Z", "z"
        # ruby builds a US-ASCII string of the rest and matches it; a byte
        # over 0x7f there makes the match raise
        k = si
        while k < slen
          raise ArgumentError, "invalid byte sequence in US-ASCII" if s.getbyte(k) > 127
          k += 1
        end
        m = ZONE_PAT.match(s.byteslice(si, slen - si))
        return __fail(h) if m.nil?
        z = m[1]
        si += m.end(0)
        h[:zone] = z
        h[:offset] = zone_to_diff(z)
      when "%"
        return __fail(h) if s.getbyte(si) != 37
        si += 1
      when "+"
        sub = FMT_PLUS
      else
        return __fail(h) if s.getbyte(si) != 37
        si += 1
        if fi < flen
          return __fail(h) if si >= slen || s.getbyte(si) != f.getbyte(fi)
          si += 1
        end
      end
      if sub
        l = __internal(s, si, slen, sub, sub.bytesize, h)
        return 0 if h[:_fail]
        si += l
      end
      fi += 1 # matched
    end
    si - si0
  end

  def self.__string_value(v)
    return v if v.is_a?(String)
    return v.to_str if v.respond_to?(:to_str)
    raise TypeError, "no implicit conversion of #{v.nil? ? 'nil' : v.class} into String"
  end

  def self.__ascii_compat?(s)
    e = s.encoding
    !e.respond_to?(:ascii_compatible?) || e.ascii_compatible?
  end

  # Date._strptime(str, fmt = '%F'): the hash of fields, or nil.
  def self._strptime(str, fmt = "%F")
    str = __string_value(str)
    raise ArgumentError, "string should have ASCII compatible encoding" unless __ascii_compat?(str)
    fmt = __string_value(fmt)
    raise ArgumentError, "format should have ASCII compatible encoding" unless __ascii_compat?(fmt)
    s = str.b
    f = fmt.b
    h = {}
    slen = s.bytesize
    si = __internal(s, 0, slen, f, f.bytesize, h)
    h[:leftover] = s.byteslice(si, slen - si) if slen > si
    return nil if h[:_fail]

    cent = h.delete(:_cent)
    unless cent.nil?
      y = h[:cwyear]
      h[:cwyear] = y + cent * 100 unless y.nil?
      y = h[:year]
      h[:year] = y + cent * 100 unless y.nil?
    end
    merid = h.delete(:_merid)
    unless merid.nil?
      hr = h[:hour]
      h[:hour] = hr % 12 + merid unless hr.nil?
    end

    enc = str.encoding
    h[:zone] = h[:zone].force_encoding(enc) unless h[:zone].nil?
    h[:leftover] = h[:leftover].force_encoding(enc) unless h[:leftover].nil?
    h
  end

  # ------------------------------------------------- date_zone_to_diff

  def self.__end_with_word(s, l, w)
    n = w.bytesize
    return 0 if l <= n || !__space?(s.getbyte(l - n - 1))
    return 0 unless __case_eq?(s, l - n, w, n)
    n += 1
    n += 1 while l > n && __space?(s.getbyte(l - n - 1))
    n
  end

  def self.__shrunk_size(s, l)
    ni = 0
    sp = false
    i = 0
    while i < l
      if __space?(s.getbyte(i))
        sp = true
      else
        ni += 1 if sp
        sp = false
        ni += 1
      end
      i += 1
    end
    ni < l ? ni : 0
  end

  def self.__shrink_space(s, l)
    d = "".b
    sp = false
    i = 0
    while i < l
      b = s.getbyte(i)
      if __space?(b)
        sp = true
      else
        d << " " if sp
        sp = false
        d << b.chr
      end
      i += 1
    end
    d
  end

  # strtoul over the digits at s[i..]: [value, index after them]
  def self.__strtoul(s, i)
    j = i
    j += 1 while j < s.bytesize && __digit?(s.getbyte(j))
    [j > i ? s.byteslice(i, j - i).to_i : 0, j]
  end

  # ruby_scan_digits(base 10) of at most n bytes: [value, count]
  def self.__scan_digits(s, i, n)
    k = 0
    v = 0
    while k < n && i + k < s.bytesize && __digit?(s.getbyte(i + k))
      v = v * 10 + (s.getbyte(i + k) - 48)
      k += 1
    end
    [v, k]
  end

  # The UTC offset in seconds a zone name or numeric zone stands for, or nil.
  def self.zone_to_diff(str)
    s = str.b
    l = s.bytesize
    dst = false
    w = __end_with_word(s, l, "time")
    if w > 0
      wtime = w
      l -= w
      if (w = __end_with_word(s, l, "standard")) > 0
        l -= w
      elsif (w = __end_with_word(s, l, "daylight")) > 0
        l -= w
        dst = true
      else
        l += wtime
      end
    elsif (w = __end_with_word(s, l, "dst")) > 0
      l -= w
      dst = true
    end

    sl = __shrunk_size(s, l)
    zn = nil
    if sl <= 0
      sl = l
      zn = s.byteslice(0, l)
    elsif sl <= MAX_WORD_LENGTH
      zn = __shrink_space(s, l)
      sl = zn.bytesize
    end
    if zn && sl > 0 && sl <= MAX_WORD_LENGTH
      key = "".b
      i = 0
      while i < sl
        key << __lower(zn.getbyte(i)).chr
        i += 1
      end
      off = ZONES[key]
      unless off.nil?
        off += 3600 if dst
        return off
      end
    end

    p = 0
    if l > 3 && (__case_eq?(s, 0, "gmt", 3) || __case_eq?(s, 0, "utc", 3))
      p = 3
      l -= 3
    end
    b = __at(s, p, s.bytesize)
    return nil unless b == 43 || b == 45
    sign = b == 45
    p += 1
    l -= 1
    stop = p + l
    hour = 0
    min = 0
    sec = 0
    hour, q = __strtoul(s, p)
    nb = __at(s, q, s.bytesize)
    if nb == 58 # ':'
      return nil if hour > 23
      min, q = __strtoul(s, q + 1)
      return nil if min > 59
      if __at(s, q, s.bytesize) == 58
        sec, q = __strtoul(s, q + 1)
        return nil if sec > 59
      end
    elsif nb == 44 || nb == 46 # ',' '.'
      return nil if hour > 23
      q += 1
      n = stop - q
      n = 7 if n > 7
      sec, n = __scan_digits(s, q, n)
      q += n
      if q < stop
        d = s.getbyte(q)
        sec += 1 if d >= 53 + (sec.odd? ? 0 : 1) && d <= 57 # round half to even
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
      off = Rational(sec, 10**(n - 2)) + hour * 3600
      return off.denominator == 1 ? off.numerator : off
    elsif l > 2
      hour, = __scan_digits(s, p, 2 - l % 2)
      min, = __scan_digits(s, p + 2 - l % 2, 2) if l >= 3
      sec, = __scan_digits(s, p + 4 - l % 2, 2) if l >= 5
    end
    sec += min * 60 + hour * 3600
    sec = -sec if sign
    sec
  end

  # ------------------------------------------------- calendar (date_core.c c_*)
  # Integer forms of the C's double expressions: floor(365.25 * x) is
  # (1461 * x).div(4), floor(30.6001 * x) is (306001 * x).div(10000), ...

  def self.c_civil_to_jd(y, m, d, sg)
    if m <= 2
      y -= 1
      m += 12
    end
    a = y.div(100)
    b = 2 - a + a.div(4)
    jd = (1461 * (y + 4716)).div(4) + (306001 * (m + 1)).div(10000) + d + b - 1524
    if jd < sg
      [jd - b, 0]
    else
      [jd, 1]
    end
  end

  def self.c_jd_to_civil(jd, sg)
    if jd < sg
      a = jd
    else
      x = (4 * jd - 7468865).div(146097)
      a = jd + 1 + x - x.div(4)
    end
    b = a + 1524
    c = (100 * b - 12210).div(36525)
    d = (1461 * c).div(4)
    e = ((b - d) * 10000).div(306001)
    dom = b - d - (306001 * e).div(10000)
    if e <= 13
      [c - 4716, e - 1, dom]
    else
      [c - 4715, e - 13, dom]
    end
  end

  # -> [rm, rd, rjd, ns] or nil
  def self.c_valid_civil_p(y, m, d, sg)
    m += 13 if m < 0
    return nil if m < 1 || m > 12
    if d < 0
      r = c_find_ldom(y, m, sg)
      return nil if r.nil?
      ry, rm, rd = c_jd_to_civil(r[0] + d + 1, sg)
      return nil if ry != y || rm != m
      d = rd
    end
    rjd, ns = c_civil_to_jd(y, m, d, sg)
    ry, rm, rd = c_jd_to_civil(rjd, sg)
    return nil if ry != y || rm != m || rd != d
    [rm, rd, rjd, ns]
  end

  def self.c_find_fdoy(y, sg)
    d = 1
    while d < 31
      r = c_valid_civil_p(y, 1, d, sg)
      return [r[2], r[3]] if r
      d += 1
    end
    nil
  end

  def self.c_find_ldoy(y, sg)
    i = 0
    while i < 30
      r = c_valid_civil_p(y, 12, 31 - i, sg)
      return [r[2], r[3]] if r
      i += 1
    end
    nil
  end

  def self.c_find_ldom(y, m, sg)
    i = 0
    while i < 30
      r = c_valid_civil_p(y, m, 31 - i, sg)
      return [r[2], r[3]] if r
      i += 1
    end
    nil
  end

  def self.__fdoy_jd(y, sg)
    r = c_find_fdoy(y, sg)
    r ? r[0] : 0
  end

  def self.c_ordinal_to_jd(y, d, sg)
    rjd = __fdoy_jd(y, sg) + d - 1
    [rjd, rjd < sg ? 0 : 1]
  end

  def self.c_jd_to_ordinal(jd, sg)
    ry, = c_jd_to_civil(jd, sg)
    [ry, jd - __fdoy_jd(ry, sg) + 1]
  end

  def self.c_commercial_to_jd(y, w, d, sg)
    rjd2 = __fdoy_jd(y, sg) + 3
    rjd = (rjd2 - (rjd2 % 7)) + 7 * (w - 1) + (d - 1)
    [rjd, rjd < sg ? 0 : 1]
  end

  def self.c_jd_to_commercial(jd, sg)
    a, = c_jd_to_civil(jd - 3, sg)
    rjd2, = c_commercial_to_jd(a + 1, 1, 1, sg)
    if jd >= rjd2
      ry = a + 1
    else
      rjd2, = c_commercial_to_jd(a, 1, 1, sg)
      ry = a
    end
    rd = (jd + 1) % 7
    rd = 7 if rd == 0
    [ry, 1 + (jd - rjd2).div(7), rd]
  end

  def self.c_weeknum_to_jd(y, w, d, f, sg)
    rjd2 = __fdoy_jd(y, sg) + 6
    rjd = (rjd2 - ((rjd2 - f) + 1) % 7 - 7) + 7 * w + d
    [rjd, rjd < sg ? 0 : 1]
  end

  def self.c_jd_to_weeknum(jd, f, sg)
    ry, = c_jd_to_civil(jd, sg)
    rjd = __fdoy_jd(ry, sg) + 6
    j = jd - (rjd - ((rjd - f) + 1) % 7) + 7
    [ry, j.div(7), j % 7]
  end

  def self.c_valid_ordinal_p(y, d, sg)
    if d < 0
      r = c_find_ldoy(y, sg)
      return nil if r.nil?
      ry2, rd2 = c_jd_to_ordinal(r[0] + d + 1, sg)
      return nil if ry2 != y
      d = rd2
    end
    rjd, ns = c_ordinal_to_jd(y, d, sg)
    ry2, rd2 = c_jd_to_ordinal(rjd, sg)
    return nil if ry2 != y || rd2 != d
    [d, rjd, ns]
  end

  def self.__leap?(y, gregorian)
    gregorian ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) : y % 4 == 0
  end

  MONTH_DAYS = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

  # c_valid_gregorian_p / c_valid_julian_p -> [rm, rd] or nil
  def self.c_valid_proleptic_p(y, m, d, gregorian)
    m += 13 if m < 0
    return nil if m < 1 || m > 12
    last = MONTH_DAYS[m]
    last = 29 if m == 2 && __leap?(y, gregorian)
    d = last + d + 1 if d < 0
    return nil if d < 1 || d > last
    [m, d]
  end

  def self.c_valid_commercial_p(y, w, d, sg)
    d += 8 if d < 0
    if w < 0
      rjd2, = c_commercial_to_jd(y + 1, 1, 1, sg)
      ry2, rw2, = c_jd_to_commercial(rjd2 + w * 7, sg)
      return nil if ry2 != y
      w = rw2
    end
    rjd, ns = c_commercial_to_jd(y, w, d, sg)
    ry2, rw, rd = c_jd_to_commercial(rjd, sg)
    return nil if y != ry2 || w != rw || d != rd
    [rw, rd, rjd, ns]
  end

  def self.c_valid_weeknum_p(y, w, d, f, sg)
    d += 7 if d < 0
    if w < 0
      rjd2, = c_weeknum_to_jd(y + 1, 1, f, f, sg)
      ry2, rw2, = c_jd_to_weeknum(rjd2 + w * 7, f, sg)
      return nil if ry2 != y
      w = rw2
    end
    rjd, ns = c_weeknum_to_jd(y, w, d, f, sg)
    ry2, rw, rd = c_jd_to_weeknum(rjd, f, sg)
    return nil if y != ry2 || w != rw || d != rd
    [rw, rd, rjd, ns]
  end

  def self.c_valid_time_p(h, min, s)
    h += 24 if h < 0
    min += 60 if min < 0
    s += 60 if s < 0
    return nil if h < 0 || h > 24 || min < 0 || min > 59 || s < 0 || s > 59 ||
                  (h == 24 && (min > 0 || s > 0))
    [h, min, s]
  end

  def self.c_valid_start_p(sg)
    return false if sg.is_a?(Float) && sg.nan?
    return true if sg.is_a?(Float) && sg.infinite?
    !(sg < REFORM_BEGIN_JD || sg > REFORM_END_JD)
  end

  # ------------------------------------------------- big years (decode_year)

  def self.__guess_style(y, sg)
    return sg if sg.is_a?(Float) && sg.infinite?
    return (y > 0 ? GREGORIAN : JULIAN) if y > FIXNUM_MAX || y < FIXNUM_MIN
    return JULIAN if y < 1582
    return GREGORIAN if y > 1930
    0
  end

  # -> [nth, ry]
  def self.__decode_year(y, style)
    period = style < 0 ? CM_PERIOD_GCY : CM_PERIOD_JCY
    t = y + 4712
    nth = t.div(period)
    t %= period if nth != 0
    [nth, t - 4712]
  end

  # Each returns the jd (Integer) the fields name, or nil when they name none.
  # `yield` is the c_valid_* call over (year, sg).
  def self.__valid_by_style(y, sg)
    style = __guess_style(y, sg)
    if style == 0
      r = yield(y, sg)
      r && r[-2]
    else
      nth, ry = __decode_year(y, style)
      r = yield(ry, style)
      r && CM_PERIOD * nth + r[-2]
    end
  end

  def self.valid_ordinal_jd(y, d, sg)
    __valid_by_style(y, sg) { |yy, s| c_valid_ordinal_p(yy, d, s) }
  end

  def self.valid_civil_jd(y, m, d, sg)
    style = __guess_style(y, sg)
    if style == 0
      r = c_valid_civil_p(y, m, d, sg)
      return r && r[2]
    end
    nth, ry = __decode_year(y, style)
    r = c_valid_proleptic_p(ry, m, d, style < 0)
    return nil if r.nil?
    rjd, = c_civil_to_jd(ry, r[0], r[1], style)
    CM_PERIOD * nth + rjd
  end

  def self.valid_commercial_jd(y, w, d, sg)
    __valid_by_style(y, sg) { |yy, s| c_valid_commercial_p(yy, w, d, s) }
  end

  def self.valid_weeknum_jd(y, w, d, f, sg)
    __valid_by_style(y, sg) { |yy, s| c_valid_weeknum_p(yy, w, d, f, s) }
  end

  # ------------------------------------------------- frags (date_core.c rt_*)

  # rt_rewrite_frags: :seconds (from %s / %Q) becomes :jd and a time of day.
  def self.rewrite_frags(hash)
    seconds = hash.delete(:seconds)
    unless seconds.nil?
      offset = hash[:offset]
      seconds += offset unless offset.nil?
      d = seconds.div(DAY_IN_SECONDS)
      fr = seconds % DAY_IN_SECONDS
      h = fr.div(3600)
      fr %= 3600
      min = fr.div(60)
      fr %= 60
      s = fr.div(1)
      fr %= 1
      hash[:jd] = UNIX_EPOCH_IN_CJD + d
      hash[:hour] = h
      hash[:min] = min
      hash[:sec] = s
      hash[:sec_fraction] = fr
    end
    hash
  end

  COMPLETE_TAB = [
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
    [nil, [:year, :wnum1, :cwday, :hour, :min, :sec]],
  ].freeze

  def self.__datetime_class?(klass)
    return true if klass == :datetime
    return false if klass.nil? || klass == :date
    return false unless defined?(::DateTime) && klass.is_a?(Module)
    (klass <= ::DateTime) == true
  end

  # Date.today's jd (the local civil date, as date_s_today reads localtime).
  def self.today_jd
    t = Time.now
    c_civil_to_jd(t.year, t.month, t.day, GREGORIAN)[0]
  end

  # What rb_funcall(Date.today, field) answers (start = ITALY).
  def self.__day_field(jd, field)
    case field
    when :jd then jd
    when :year then c_jd_to_civil(jd, ITALY)[0]
    when :mon then c_jd_to_civil(jd, ITALY)[1]
    when :mday then c_jd_to_civil(jd, ITALY)[2]
    when :yday then c_jd_to_ordinal(jd, ITALY)[1]
    when :cwyear then c_jd_to_commercial(jd, ITALY)[0]
    when :cweek then c_jd_to_commercial(jd, ITALY)[1]
    when :cwday then c_jd_to_commercial(jd, ITALY)[2]
    when :wday then (jd + 1) % 7
    when :wnum0 then c_jd_to_weeknum(jd, 0, ITALY)[1]
    when :wnum1 then c_jd_to_weeknum(jd, 1, ITALY)[1]
    else raise NoMethodError, "undefined method '#{field}' for an instance of Date"
    end
  end

  # rt_complete_frags: picks the field set the hash fills best and completes
  # it from today (or `today` -- a jd -- when given).
  def self.complete_frags(klass, hash, today = nil)
    k = nil
    a = nil
    eno = 0
    COMPLETE_TAB.each do |x|
      n = 0
      x[1].each { |key| n += 1 unless hash[key].nil? }
      if n > eno
        eno = n
        k = x[0]
        a = x[1]
      end
    end
    e = eno
    d = nil

    if !k.nil? && a.size > e
      case k
      when :ordinal
        if hash[:year].nil?
          d ||= today || today_jd
          hash[:year] = __day_field(d, :year)
        end
        hash[:yday] = 1 if hash[:yday].nil?
      when :civil, :commercial, :wnum0, :wnum1
        a.each do |key|
          break unless hash[key].nil?
          d ||= today || today_jd
          hash[key] = __day_field(d, key)
        end
        case k
        when :civil
          hash[:mon] = 1 if hash[:mon].nil?
          hash[:mday] = 1 if hash[:mday].nil?
        when :commercial
          hash[:cweek] = 1 if hash[:cweek].nil?
          hash[:cwday] = 1 if hash[:cwday].nil?
        when :wnum0
          hash[:wnum0] = 0 if hash[:wnum0].nil?
          hash[:wday] = 0 if hash[:wday].nil?
        when :wnum1
          hash[:wnum1] = 0 if hash[:wnum1].nil?
          hash[:wday] = 1 if hash[:wday].nil?
        end
      when :wday
        d ||= today || today_jd
        hash[:jd] = d - __day_field(d, :wday) + hash[:wday]
      end
    end

    if k == :time && __datetime_class?(klass)
      d ||= today || today_jd
      hash[:jd] = d if hash[:jd].nil?
    end

    hash[:hour] = 0 if hash[:hour].nil?
    hash[:min] = 0 if hash[:min].nil?
    if hash[:sec].nil?
      hash[:sec] = 0
    elsif hash[:sec] > 59
      hash[:sec] = 59
    end
    hash
  end

  # rt__valid_date_frags_p: the jd the completed fields name, or nil.
  def self.valid_date_frags_p(hash, sg)
    jd = hash[:jd]
    return jd unless jd.nil?

    yday = hash[:yday]
    year = hash[:year]
    if !yday.nil? && !year.nil?
      jd = valid_ordinal_jd(year, yday, sg)
      return jd unless jd.nil?
    end

    mday = hash[:mday]
    mon = hash[:mon]
    if !mday.nil? && !mon.nil? && !year.nil?
      jd = valid_civil_jd(year, mon, mday, sg)
      return jd unless jd.nil?
    end

    wday = hash[:cwday]
    if wday.nil?
      wday = hash[:wday]
      wday = 7 if !wday.nil? && wday == 0
    end
    week = hash[:cweek]
    cwyear = hash[:cwyear]
    if !wday.nil? && !week.nil? && !cwyear.nil?
      jd = valid_commercial_jd(cwyear, week, wday, sg)
      return jd unless jd.nil?
    end

    wday = hash[:wday]
    if wday.nil?
      wday = hash[:cwday]
      wday = 0 if !wday.nil? && wday == 7
    end
    week = hash[:wnum0]
    if !wday.nil? && !week.nil? && !year.nil?
      jd = valid_weeknum_jd(year, week, wday, 0, sg)
      return jd unless jd.nil?
    end

    wday = hash[:wday]
    wday = hash[:cwday] if wday.nil?
    wday = (wday - 1) % 7 unless wday.nil?
    week = hash[:wnum1]
    if !wday.nil? && !week.nil? && !year.nil?
      jd = valid_weeknum_jd(year, week, wday, 1, sg)
      return jd unless jd.nil?
    end
    nil
  end

  # d_new_by_frags / dt_new_by_frags: [jd, df, sf, of] -- jd and df as UTC,
  # sf in nanoseconds, of in seconds -- or nil where ruby raises
  # Date::Error "invalid date". A Date's df, sf and of are 0.
  def self.new_by_frags(klass, hash, sg = ITALY, today = nil)
    sg = ITALY unless c_valid_start_p(sg)
    return nil if hash.nil?
    hash = hash.dup
    datetime = __datetime_class?(klass)

    if hash[:jd].nil? && hash[:yday].nil? &&
       !hash[:year].nil? && !hash[:mon].nil? && !hash[:mday].nil?
      jd = valid_civil_jd(hash[:year], hash[:mon], hash[:mday], sg)
      if datetime
        hash[:hour] = 0 if hash[:hour].nil?
        hash[:min] = 0 if hash[:min].nil?
        if hash[:sec].nil?
          hash[:sec] = 0
        elsif hash[:sec] == 60
          hash[:sec] = 59
        end
      end
    else
      rewrite_frags(hash)
      complete_frags(klass, hash, today)
      jd = valid_date_frags_p(hash, sg)
    end
    return nil if jd.nil?
    return [jd, 0, 0, 0] unless datetime

    t = c_valid_time_p(hash[:hour].to_i, hash[:min].to_i, hash[:sec].to_i)
    return nil if t.nil?
    df = t[0] * 3600 + t[1] * 60 + t[2]

    sf = hash[:sec_fraction]
    if sf.nil?
      sf = 0
    else
      sf *= 1_000_000_000
      sf = sf.numerator if sf.is_a?(Rational) && sf.denominator == 1
    end

    of = hash[:offset]
    if of.nil?
      of = 0
    else
      of = of.to_i
      of = 0 if of < -DAY_IN_SECONDS || of > DAY_IN_SECONDS
    end

    ldf = df - of
    if ldf < 0
      jd -= 1
      ldf += DAY_IN_SECONDS
    elsif ldf >= DAY_IN_SECONDS
      jd += 1
      ldf -= DAY_IN_SECONDS
    end
    [jd, ldf, sf, of]
  end

  def self.date_strptime(str = "-4712-01-01", fmt = "%F", sg = ITALY, today = nil)
    new_by_frags(:date, _strptime(str, fmt), sg, today)
  end

  def self.datetime_strptime(str = "-4712-01-01T00:00:00+00:00", fmt = "%FT%T%z", sg = ITALY, today = nil)
    new_by_frags(:datetime, _strptime(str, fmt), sg, today)
  end
end
