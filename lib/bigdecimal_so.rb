# frozen_string_literal: true
#
# BigDecimal's C half, written in Ruby for mere-ruby.
#
# The reference's `require "bigdecimal"` reads the gem's bigdecimal.rb, which
# requires 'bigdecimal.so' -- the C extension (ext/bigdecimal/bigdecimal.c,
# bigdecimal 4.0.1). mere-ruby cannot load a C extension, so this file is
# what 'bigdecimal.so' is here. It defines what the extension defines: the
# BigDecimal class with its constants and methods, Kernel#BigDecimal, and the
# thread-local modes. The gem's Ruby half (power, sqrt, BigMath) is shipped as
# it is and runs on top of it.
#
# A value is a sign, an Integer coefficient and a power of ten: c * 10**e,
# with c kept free of trailing zeros. Zero, the infinities and NaN are their
# own kinds. Sums and products are exact, as the extension's are; a quotient
# is computed exactly and rounded to its precision, which is what the
# extension's extra digit and sticky remainder amount to. Where the extension
# counts in its base-10**9 words (a Rational operand's precision, #_dump),
# the count is made in the same words.

class BigDecimal < Numeric
  VERSION = "4.0.1"
  BASE = 1_000_000_000

  EXCEPTION_ALL = 0xff
  EXCEPTION_INFINITY = 0x01
  EXCEPTION_NaN = 0x02
  EXCEPTION_UNDERFLOW = 0x04
  EXCEPTION_OVERFLOW = 0x01
  EXCEPTION_ZERODIVIDE = 0x10

  ROUND_MODE = 0x100
  ROUND_UP = 1
  ROUND_DOWN = 2
  ROUND_HALF_UP = 3
  ROUND_HALF_DOWN = 4
  ROUND_CEILING = 5
  ROUND_FLOOR = 6
  ROUND_HALF_EVEN = 7

  SIGN_NaN = 0
  SIGN_POSITIVE_ZERO = 1
  SIGN_NEGATIVE_ZERO = -1
  SIGN_POSITIVE_FINITE = 2
  SIGN_NEGATIVE_FINITE = -2
  SIGN_POSITIVE_INFINITE = 3
  SIGN_NEGATIVE_INFINITE = -3

  DOUBLE_FIG = 16 # BIGDECIMAL_DOUBLE_FIGURES: 1 + DBL_DIG
  BASE_FIG = 9
  VP_EXPONENT_MAX = (2**63 - 1) / BASE_FIG
  VP_EXPONENT_MIN = -VP_EXPONENT_MAX
  EXPONENT_MAX = VP_EXPONENT_MAX * BASE_FIG
  private_constant :DOUBLE_FIG, :BASE_FIG, :VP_EXPONENT_MAX, :VP_EXPONENT_MIN, :EXPONENT_MAX

  ROUNDING_NAMES = {
    up: ROUND_UP, down: ROUND_DOWN, half_up: ROUND_HALF_UP, half_down: ROUND_HALF_DOWN,
    ceil: ROUND_CEILING, floor: ROUND_FLOOR, half_even: ROUND_HALF_EVEN,
    default: ROUND_HALF_UP, truncate: ROUND_DOWN, banker: ROUND_HALF_EVEN, ceiling: ROUND_CEILING
  }.freeze
  private_constant :ROUNDING_NAMES

  class << self
    undef_method :new

    # (the extension has no allocator; values are made only by __make)
    def allocate
      raise TypeError, "allocator undefined for BigDecimal" unless @__making
      super
    end

    # ---- the thread-local modes (rb_thread_local_aref, as the extension) --

    def __exception_mode = (Thread.current[:"BigDecimal.exception_mode"] ||= 0)
    def __rounding_mode = (Thread.current[:"BigDecimal.rounding_mode"] ||= ROUND_HALF_UP)
    def __limit = (Thread.current[:"BigDecimal.precision_limit"] ||= 0)

    def mode(which, val = nil)
      f = Integer(which)
      if (f & EXCEPTION_ALL) != 0
        fo = __exception_mode
        return fo if val.nil?
        raise ArgumentError, "second argument must be true or false" unless val == true || val == false
        [EXCEPTION_INFINITY, EXCEPTION_NaN, EXCEPTION_UNDERFLOW, EXCEPTION_ZERODIVIDE].each do |bit|
          next if (f & bit) == 0
          fo = val ? (fo | bit) : (fo & ~bit)
        end
        Thread.current[:"BigDecimal.exception_mode"] = fo
        return fo
      end
      if f == ROUND_MODE
        return __rounding_mode if val.nil?
        sw = __check_rounding_mode(val)
        Thread.current[:"BigDecimal.rounding_mode"] = sw
        return sw
      end
      raise TypeError, "first argument for BigDecimal.mode invalid"
    end

    def __check_rounding_mode(v)
      if v.is_a?(Symbol)
        return ROUNDING_NAMES.fetch(v) { raise ArgumentError, "invalid rounding mode (#{v})" }
      end
      n = Integer(v)
      raise ArgumentError, "invalid rounding mode (#{v.inspect})" unless (ROUND_UP..ROUND_HALF_EVEN).cover?(n)
      n
    end

    def __rounding_option(opts)
      mode = opts[:half]
      return __rounding_mode if mode.nil?
      s = mode.is_a?(Symbol) ? mode.to_s : (String.try_convert(mode) or raise ArgumentError, "invalid rounding mode (#{mode.inspect})")
      case s.downcase
      when "up" then ROUND_HALF_UP
      when "even" then ROUND_HALF_EVEN
      when "down" then ROUND_HALF_DOWN
      else raise ArgumentError, "invalid rounding mode (#{s})"
      end
    end

    def limit(n = nil)
      cur = __limit
      unless n.nil?
        n = Integer(n)
        raise ArgumentError, "argument must be positive" if n < 0
        Thread.current[:"BigDecimal.precision_limit"] = n
      end
      cur
    end

    def double_fig = DOUBLE_FIG

    def save_exception_mode
      saved = __exception_mode
      yield
    ensure
      Thread.current[:"BigDecimal.exception_mode"] = saved
    end

    def save_rounding_mode
      saved = __rounding_mode
      yield
    ensure
      Thread.current[:"BigDecimal.rounding_mode"] = saved
    end

    def save_limit
      saved = __limit
      yield
    ensure
      Thread.current[:"BigDecimal.precision_limit"] = saved
    end

    def interpret_loosely(str)
      __check(__parse(String(str), false, true))
    end

    def _load(str)
      s = String(str)
      i = s.index(":")
      head = i ? s[0, i] : s
      raise TypeError, "load failed: invalid character in the marshaled string" unless head.match?(/\A\d*\z/)
      __check(__parse(i ? s[(i + 1)..] : s, true, true))
    end

    # ---- making values ----------------------------------------------------

    # kind: :finite (c > 0), :zero, :inf, :nan; sign +1/-1
    def __make(kind, sign, c = 0, e = 0)
      @__making = true
      begin
        o = allocate
      ensure
        @__making = false
      end
      if kind == :finite
        if c == 0
          kind = :zero
          c = 0
          e = 0
        else
          # (trailing zeros go in one step: a quotient can have 10**5 digits)
          if c % 10 == 0
            ds = c.to_s
            kept = ds.sub(/0+\z/, "")
            e += ds.length - kept.length
            c = kept.to_i
          end
          # the extension's exponent counts base-10**9 words (AddExponent)
          w = (c.to_s.length - 1 + e).div(BASE_FIG) + 1
          if w > VP_EXPONENT_MAX
            __exception(EXCEPTION_OVERFLOW, "Exponent overflow")
            kind = :inf
          elsif w < VP_EXPONENT_MIN
            __exception(EXCEPTION_UNDERFLOW, "Exponent underflow")
            kind = :zero
          end
        end
      end
      o.instance_variable_set(:@kind, kind)
      o.instance_variable_set(:@sign, kind == :nan ? 0 : sign)
      o.instance_variable_set(:@c, c)
      o.instance_variable_set(:@e, e)
      o.freeze
    end

    def __nan = __make(:nan, 0)
    def __inf(sign) = __make(:inf, sign)
    def __zero(sign = 1) = __make(:zero, sign)

    # FloatDomainError when the exception mode asks for it (CheckGetValue)
    def __check(v, always = false)
      return v unless v
      k = v.__kind
      if k == :nan
        __exception(EXCEPTION_NaN, "Computation results in 'NaN' (Not a Number)", always)
      elsif k == :inf
        __exception(EXCEPTION_INFINITY, v.__sign > 0 ? "Computation results in 'Infinity'" : "Computation results in '-Infinity'", always)
      end
      v
    end

    def __exception(flag, msg, always = false)
      raise FloatDomainError, msg if always || (__exception_mode & flag) != 0
    end

    # VpAlloc: strict is BigDecimal(), loose is interpret_loosely
    def __parse(src, strict, exc)
      s = src.sub(/\A\s+/, "")
      if (m = s.match(/\A(Infinity|\+Infinity|-Infinity|NaN)\s*\z/))
        return __nan if m[1] == "NaN"
        return __inf(m[1].start_with?("-") ? -1 : 1)
      end
      s = s[1..] if s.start_with?("#")
      sign = 1
      i = 0
      if s[0] == "-" || s[0] == "+"
        sign = -1 if s[0] == "-"
        i = 1
      end
      int = +""
      bad = false
      stop = false
      n = s.length
      while i < n
        ch = s[i]
        if !strict && ch.match?(/\s/)
          stop = true
          break
        end
        if ch == "_"
          if int.length > 0
            nx = s[i + 1]
            if nx.nil? || nx.match?(/\s/) || nx.match?(/\d/)
              i += 1
              next
            end
            unless strict
              stop = true
              break
            end
          end
          bad = true
          break
        end
        break unless ch.match?(/\d/)
        int << ch
        i += 1
      end
      frac = +""
      exp = +""
      exp_seen = false
      exp_sign = 1
      if !bad && !stop && i < n
        if s[i] == "."
          i += 1
          while i < n
            ch = s[i]
            if !strict && ch.match?(/\s/)
              stop = true
              break
            end
            if ch == "_"
              if frac.length > 0 && s[i + 1]&.match?(/\d/)
                i += 1
                next
              end
              unless strict
                stop = true
                break
              end
              bad = true
              break
            end
            break unless ch.match?(/\d/)
            frac << ch
            i += 1
          end
        end
        if !bad && !stop && i < n && "eEdD".include?(s[i])
          exp_seen = true
          i += 1
          if s[i] == "-" || s[i] == "+"
            exp_sign = -1 if s[i] == "-"
            i += 1
          end
          while i < n
            ch = s[i]
            if !strict && ch.match?(/\s/)
              stop = true
              break
            end
            if ch == "_"
              if exp.length > 0 && s[i + 1]&.match?(/\d/)
                i += 1
                next
              end
              unless strict
                exp_seen = false if exp.empty?
                stop = true
                break
              end
              bad = true
              break
            end
            break unless ch.match?(/\d/)
            exp << ch
            i += 1
          end
        end
        if !bad && !stop && i < n
          i += 1 while i < n && s[i].match?(/\s/)
          bad = true if i < n && strict
        end
      end
      if bad || (strict && ((int.empty? && frac.empty?) || (exp_seen && exp.empty?)))
        return __zero(1) unless strict
        return nil unless exc
        raise ArgumentError, "invalid value for BigDecimal(): \"#{src}\""
      end
      c = (int + frac).to_i
      e = (exp.empty? ? 0 : exp_sign * exp.to_i) - frac.length
      return __zero(sign) if c == 0
      # the decimal exponent, rounded up to whole words, must fit (VpCtoV)
      d = c.to_s.length + e
      d += (BASE_FIG - d % BASE_FIG) % BASE_FIG
      if d > EXPONENT_MAX || d < -EXPONENT_MAX - (BASE_FIG - 1)
        return __zero(sign) unless d > 0
        __exception(EXCEPTION_INFINITY, "exponent overflow")
        return __inf(sign)
      end
      __make(:finite, sign, c, e)
    end

    def __from_float(f, digs, exc)
      return __check(__nan) if f.nan?
      return __check(__inf(f > 0 ? 1 : -1)) if f.infinite?
      return __zero(1.0 / f < 0 ? -1 : 1) if f == 0.0
      if digs > DOUBLE_FIG
        return nil unless exc
        raise ArgumentError, "precision too large."
      end
      str = if digs == 0
              f.abs.to_s
            else
              format("%.#{digs - 1}e", f.abs)
            end
      v = __parse(str, true, true)
      v = v.__sigdigits(DOUBLE_FIG, ROUND_DOWN) if v.n_significant_digits > DOUBLE_FIG
      f < 0 ? -v : v
    end

    def __convert(val, digs, exc)
      case val
      when nil, true, false
        return nil unless exc
        raise TypeError, "can't convert #{val.inspect} into BigDecimal"
      when BigDecimal
        return __check(val)
      when Integer
        return val == 0 ? __zero(1) : __make(:finite, val < 0 ? -1 : 1, val.abs, 0)
      when Float
        return __from_float(val, digs.nil? ? 0 : digs, exc)
      when Rational
        if digs.nil?
          return nil unless exc
          raise ArgumentError, "can't omit precision for a Rational."
        end
        return __convert(val.numerator, nil, true).div(val.denominator, digs)
      when Complex
        raise ArgumentError, "Unable to make a BigDecimal from non-zero imaginary number" unless val.imaginary.zero?
        return __convert(val.real, digs, exc)
      when String
        return __check(__parse(val, true, exc))
      end
      str = String.try_convert(val)
      unless str
        return nil unless exc
        raise TypeError, "can't convert #{val.class} into BigDecimal"
      end
      __check(__parse(str, true, exc))
    end

    # an operand: Integer, Float, Rational (at prec digits) or a BigDecimal;
    # nil for what must be coerced instead
    def __operand(v, prec)
      case v
      when BigDecimal then v
      when Integer then __convert(v, nil, true)
      when Float then __from_float(v, 0, true)
      when Rational then __convert(v.numerator, nil, true).div(v.denominator, prec)
      end
    end

    def __round_div(num, den, mode, neg)
      q, r = num.divmod(den)
      return q if r == 0
      twice = r * 2
      up = case mode
           when ROUND_UP then true
           when ROUND_DOWN then false
           when ROUND_HALF_UP then twice >= den
           when ROUND_HALF_DOWN then twice > den
           when ROUND_HALF_EVEN then twice > den || (twice == den && q.odd?)
           when ROUND_CEILING then !neg
           when ROUND_FLOOR then neg
           else twice >= den
           end
      up ? q + 1 : q
    end
  end

  # ---- the parts -----------------------------------------------------------

  def __kind = @kind
  def __sign = @sign
  def __c = @c
  def __e = @e

  def __finite? = @kind == :finite

  # the position (a power of ten) of the most significant digit
  def __msd = @c.to_s.length - 1 + @e

  # this value rounded to n digits after the point (n < 0: before it)
  def __round_at(n, mode)
    return self unless @kind == :finite
    return self if @e >= -n
    den = 10**(-n - @e)
    q = BigDecimal.__round_div(@c, den, mode, @sign < 0)
    return BigDecimal.__zero(@sign) if q == 0
    BigDecimal.__make(:finite, @sign, q, -n)
  end

  # this value rounded to n significant digits (VpLeftRound)
  def __sigdigits(n, mode = BigDecimal.__rounding_mode)
    return self unless @kind == :finite && n > 0
    __round_at(n - __msd - 1, mode)
  end

  # the precision limit, applied to a new result (VpLimitRound)
  def __limited
    l = BigDecimal.__limit
    l > 0 ? __sigdigits(l) : self
  end

  # the extension's word count for this value (Prec, in base 10**9 words)
  def __words
    return 1 unless @kind == :finite
    (__msd.div(BASE_FIG)) - (@e.div(BASE_FIG)) + 1
  end

  def __coerce_prec(prec)
    prec = __words * BASE_FIG if prec == 0
    prec < 2 * DOUBLE_FIG ? 2 * DOUBLE_FIG : prec
  end

  def __operand!(v, prec = 0)
    b = BigDecimal.__operand(v, __coerce_prec(prec))
    return b if b
    s = (v.nil? || v == true || v == false || v.is_a?(Symbol) || v.is_a?(Integer)) ? v.inspect : v.class.to_s
    raise TypeError, "#{s} can't be coerced into BigDecimal"
  end

  def __coercible?(v) = v.is_a?(BigDecimal) || v.is_a?(Integer) || v.is_a?(Float) || v.is_a?(Rational)

  # what the other operand's coerce makes of it (rb_num_coerce_bin)
  def __via_coerce(v, op)
    unless v.respond_to?(:coerce)
      raise TypeError, "#{__cname(v)} can't be coerced into BigDecimal"
    end
    a, b = v.coerce(self)
    a.public_send(op, b)
  end

  def __cname(v) = (v.nil? || v == true || v == false || v.is_a?(Integer) || v.is_a?(Float)) ? v.inspect : v.class.to_s

  # ---- predicates and parts ---------------------------------------------------

  def nan? = @kind == :nan
  def infinite? = @kind == :inf ? @sign : nil
  def finite? = @kind == :finite || @kind == :zero
  def zero? = @kind == :zero
  def nonzero? = @kind == :zero ? nil : self

  def sign
    case @kind
    when :nan then SIGN_NaN
    when :zero then @sign > 0 ? SIGN_POSITIVE_ZERO : SIGN_NEGATIVE_ZERO
    when :inf then @sign > 0 ? SIGN_POSITIVE_INFINITE : SIGN_NEGATIVE_INFINITE
    else @sign > 0 ? SIGN_POSITIVE_FINITE : SIGN_NEGATIVE_FINITE
    end
  end

  def exponent = @kind == :finite ? __msd + 1 : 0

  def precision
    return 0 unless @kind == :finite
    m = __msd
    (m >= 0 ? m + 1 : 0) + scale
  end

  def scale = @kind == :finite && @e < 0 ? -@e : 0

  def precision_scale = [precision, scale]

  def n_significant_digits = @kind == :finite ? @c.to_s.length : 0

  def split
    digits = case @kind
             when :nan then "NaN"
             when :inf then "Infinity"
             when :zero then "0"
             else @c.to_s
             end
    s = @kind == :nan ? 0 : (@sign < 0 ? -1 : 1)
    [s, digits, 10, exponent]
  end

  def hash
    case @kind
    when :finite then [@sign, @c, @e].hash
    when :zero then 1.hash
    when :nan then 0.hash
    else (3 * @sign).hash
    end
  end

  def dup = self
  alias clone dup

  # ---- conversions -------------------------------------------------------------

  def __check_num!
    if @kind == :nan
      raise FloatDomainError, "Computation results in 'NaN' (Not a Number)"
    elsif @kind == :inf
      raise FloatDomainError, @sign > 0 ? "Computation results in 'Infinity'" : "Computation results in '-Infinity'"
    end
  end
  private :__check_num!

  def to_i
    __check_num!
    return 0 if @kind == :zero
    v = @e >= 0 ? @c * 10**@e : @c / 10**(-@e)
    @sign < 0 ? -v : v
  end
  alias to_int to_i

  def to_r
    __check_num!
    return Rational(0, 1) if @kind == :zero
    num = @sign < 0 ? -@c : @c
    @e >= 0 ? Rational(num * 10**@e, 1) : Rational(num, 10**(-@e))
  end

  def to_f
    case @kind
    when :nan then return Float::NAN
    when :inf then return @sign > 0 ? Float::INFINITY : -Float::INFINITY
    when :zero then return @sign > 0 ? 0.0 : -0.0
    end
    e10 = exponent
    if e10 > 308 + BASE_FIG
      BigDecimal.__exception(EXCEPTION_OVERFLOW, "BigDecimal to Float conversion")
      return @sign > 0 ? Float::INFINITY : -Float::INFINITY
    end
    if e10 < -307 - 15
      BigDecimal.__exception(EXCEPTION_UNDERFLOW, "BigDecimal to Float conversion")
      return @sign > 0 ? 0.0 : -0.0
    end
    f = to_s.to_f
    if f.infinite?
      BigDecimal.__exception(EXCEPTION_OVERFLOW, "BigDecimal to Float conversion")
    elsif f == 0.0
      BigDecimal.__exception(EXCEPTION_UNDERFLOW, "BigDecimal to Float conversion")
      f = @sign > 0 ? 0.0 : -0.0
    end
    f
  end

  def coerce(other)
    b = __operand!(other)
    [BigDecimal.__check(b), self]
  end

  # ---- printing ----------------------------------------------------------------

  def __special_s(plus)
    case @kind
    when :nan then "NaN"
    when :inf then @sign > 0 ? (plus == 1 ? " Infinity" : plus == 2 ? "+Infinity" : "Infinity") : "-Infinity"
    when :zero
      return "-0.0" if @sign < 0
      plus == 1 ? " 0.0" : plus == 2 ? "+0.0" : "0.0"
    end
  end
  private :__special_s

  def to_s(fmt = nil) = __format(fmt).dup.force_encoding(Encoding::US_ASCII)

  # (not through #to_s: an override of to_s leaves inspect alone)
  def inspect = __format(nil).dup.force_encoding(Encoding::BINARY)

  def __format(fmt)
    plus = 0
    group = 0
    f_format = false
    if fmt.is_a?(String)
      s = fmt
      if s.start_with?(" ")
        plus = 1
        s = s[1..]
      elsif s.start_with?("+")
        plus = 2
        s = s[1..]
      end
      s.each_char do |ch|
        next if ch.match?(/\s/)
        unless ch.match?(/\d/)
          f_format = true if ch == "F" || ch == "f"
          break
        end
        group = group * 10 + ch.to_i
      end
    elsif !fmt.nil?
      m = Integer(fmt)
      raise ArgumentError, "argument must be positive" if m <= 0
      group = m
    end
    sp = __special_s(plus)
    return sp if sp
    head = @sign < 0 ? "-" : plus == 1 ? " " : plus == 2 ? "+" : ""
    digits = @c.to_s
    if f_format
      point = digits.length + @e # digits before the point
      if point <= 0
        ip = "0"
        fp = "0" * -point + digits
      elsif @e >= 0
        ip = digits + "0" * @e
        fp = ""
      else
        ip = digits[0, point]
        fp = digits[point..]
      end
      if group > 0
        ip = ip.reverse.scan(/.{1,#{group}}/).join(" ").reverse if ip != "0" || point > 0
        fp = fp.scan(/.{1,#{group}}/).join(" ")
      end
      fp = "0" if fp.empty?
      head + ip + "." + fp
    else
      mant = group > 0 ? digits.scan(/.{1,#{group}}/).join(" ") : digits
      head + "0." + mant + "e" + exponent.to_s
    end
  end

  def _dump(_limit = nil) = "#{__words * BASE_FIG}:#{to_s}"

  # ---- arithmetic ----------------------------------------------------------------

  def +@ = self

  def -@
    case @kind
    when :nan then self
    else BigDecimal.__make(@kind, -@sign, @c, @e)
    end
  end

  def abs
    return self if @kind == :nan
    BigDecimal.__make(@kind, 1, @c, @e)
  end

  # sum or difference (op +1 / -1), exact, then prec digits or the limit
  def __addsub(b, op, prec)
    return BigDecimal.__check(self) if @kind == :nan
    return BigDecimal.__check(b) if b.__kind == :nan
    bs = b.__sign * op
    if @kind == :inf || b.__kind == :inf
      if @kind == :inf && b.__kind == :inf
        return BigDecimal.__check(@sign == bs ? self : BigDecimal.__nan)
      end
      return BigDecimal.__check(@kind == :inf ? self : BigDecimal.__inf(bs))
    end
    if @kind == :zero && b.__kind == :zero
      r = BigDecimal.__zero(@sign < 0 && bs < 0 ? -1 : 1)
    elsif @kind == :zero
      r = BigDecimal.__make(:finite, bs, b.__c, b.__e)
    elsif b.__kind == :zero
      r = self
    else
      e = [@e, b.__e].min
      x = (@sign * @c) * 10**(@e - e) + (bs * b.__c) * 10**(b.__e - e)
      r = x == 0 ? BigDecimal.__zero(1) : BigDecimal.__make(:finite, x < 0 ? -1 : 1, x.abs, e)
    end
    r = prec > 0 ? r.__sigdigits(prec) : r.__limited
    BigDecimal.__check(r)
  end
  protected :__addsub

  def +(other)
    return __via_coerce(other, :+) unless __coercible?(other)
    __addsub(__operand!(other), 1, 0)
  end

  def -(other)
    return __via_coerce(other, :-) unless __coercible?(other)
    __addsub(__operand!(other), -1, 0)
  end

  def add(other, n)
    n = __prec_arg(n)
    __addsub(__operand!(other, n), 1, n)
  end

  def sub(other, n)
    n = __prec_arg(n)
    __addsub(__operand!(other, n), -1, n)
  end

  def __prec_arg(n)
    n = Integer(n)
    raise ArgumentError, "negative precision" if n < 0
    n
  end
  private :__prec_arg

  def __mult(b, prec)
    return BigDecimal.__check(BigDecimal.__nan) if @kind == :nan || b.__kind == :nan
    s = @sign * b.__sign
    if @kind == :inf || b.__kind == :inf
      return BigDecimal.__check(BigDecimal.__nan) if @kind == :zero || b.__kind == :zero
      return BigDecimal.__check(BigDecimal.__inf(s))
    end
    r = if @kind == :zero || b.__kind == :zero
          BigDecimal.__zero(s)
        else
          BigDecimal.__make(:finite, s, @c * b.__c, @e + b.__e)
        end
    r = prec > 0 ? r.__sigdigits(prec) : r.__limited
    BigDecimal.__check(r)
  end
  protected :__mult

  def *(other)
    return __via_coerce(other, :*) unless __coercible?(other)
    __mult(__operand!(other), 0)
  end

  def mult(other, n)
    n = __prec_arg(n)
    __mult(__operand!(other, n), n)
  end

  # a / b to ix significant digits (BigDecimal_div2 with digits)
  def __divide(b, ix)
    return BigDecimal.__check(BigDecimal.__nan) if @kind == :nan || b.__kind == :nan
    s = @sign * b.__sign
    if @kind == :inf
      return BigDecimal.__check(BigDecimal.__nan) if b.__kind == :inf
      return BigDecimal.__check(BigDecimal.__inf(s))
    end
    return BigDecimal.__check(BigDecimal.__zero(s)) if b.__kind == :inf
    if b.__kind == :zero
      if @kind == :zero
        BigDecimal.__exception(EXCEPTION_NaN, "Computation results to 'NaN'")
        return BigDecimal.__check(BigDecimal.__nan)
      end
      BigDecimal.__exception(EXCEPTION_ZERODIVIDE, "Divide by zero")
      return BigDecimal.__check(BigDecimal.__inf(s))
    end
    return BigDecimal.__zero(s) if @kind == :zero
    if ix == 0
      ix = [precision, b.precision].max + DOUBLE_FIG
      ix = 2 * DOUBLE_FIG if ix < 2 * DOUBLE_FIG
      l = BigDecimal.__limit
      ix = l if l > 0 && l < ix
    end
    # exact quotient, scaled to keep ix + 1 significant digits and more
    num = @c
    den = b.__c
    e = @e - b.__e
    shift = ix + 2 + den.to_s.length - num.to_s.length
    shift = 0 if shift < 0
    num *= 10**shift
    e -= shift
    q, r = num.divmod(den)
    # the remainder decides a half-way case, as the extension's sticky digit
    q = q * 10 + (r == 0 ? 0 : 1)
    e -= 1
    v = BigDecimal.__make(:finite, s, q, e)
    BigDecimal.__check(v.__sigdigits(ix))
  end
  protected :__divide

  def /(other)
    return __via_coerce(other, :/) unless __coercible?(other)
    __divide(__operand!(other), 0)
  end

  def quo(other, n = nil)
    if n.nil? || (n = __prec_arg(n)) == 0
      return __via_coerce(other, :quo) unless __coercible?(other)
      return __divide(__operand!(other), 0)
    end
    __divide(__operand!(other, n), n)
  end

  def div(other, n = nil)
    if n.nil?
      return __via_coerce(other, :div) unless __coercible?(other)
      d, = __divmod(__operand!(other), false)
      return d.to_i
    end
    n = __prec_arg(n)
    __divide(__operand!(other, n), n)
  end

  # [quotient, modulus] as the extension's BigDecimal_DoDivmod: floored (or
  # truncated) quotient, exact remainder
  def __divmod(b, truncate)
    if @kind == :nan || b.__kind == :nan || (@kind == :inf && b.__kind == :inf)
      return [BigDecimal.__nan, BigDecimal.__nan]
    end
    raise ZeroDivisionError, "divided by 0" if b.__kind == :zero
    if @kind == :inf
      return [BigDecimal.__inf(@sign == b.__sign ? 1 : -1), BigDecimal.__nan]
    end
    return [BigDecimal.__zero(1), self] if @kind == :zero
    if b.__kind == :inf
      if !truncate && @sign * b.__sign < 0
        return [BigDecimal.__make(:finite, -1, 1, 0), b]
      end
      return [BigDecimal.__zero(1), self]
    end
    e = [@e, b.__e].min
    x = @sign * @c * 10**(@e - e)
    y = b.__sign * b.__c * 10**(b.__e - e)
    if truncate
      q = x.abs / y.abs
      q = -q if (x < 0) != (y < 0)
      m = x - q * y
    else
      q, m = x.divmod(y)
    end
    qv = q == 0 ? BigDecimal.__zero(1) : BigDecimal.__make(:finite, q < 0 ? -1 : 1, q.abs, 0)
    mv = m == 0 ? BigDecimal.__zero(@sign) : BigDecimal.__make(:finite, m < 0 ? -1 : 1, m.abs, e)
    [qv, mv]
  end
  protected :__divmod

  def %(other)
    return __via_coerce(other, :%) unless __coercible?(other)
    _, m = __divmod(__operand!(other), false)
    BigDecimal.__check(m)
  end
  alias modulo %

  def remainder(other)
    return __via_coerce(other, :remainder) unless __coercible?(other)
    _, m = __divmod(__operand!(other), true)
    BigDecimal.__check(m)
  end

  def divmod(other)
    return __via_coerce(other, :divmod) unless __coercible?(other)
    d, m = __divmod(__operand!(other), false)
    [BigDecimal.__check(d).to_i, BigDecimal.__check(m)]
  end

  # ---- rounding --------------------------------------------------------------------

  def __round_mode_for(n, mode)
    BigDecimal.__check(__round_at(n, mode))
  end
  private :__round_mode_for

  def round(*args)
    n = 0
    to_int = false
    sw = BigDecimal.__rounding_mode
    case args.size
    when 0
      to_int = true
    when 1
      if args[0].is_a?(Hash)
        sw = BigDecimal.__rounding_option(args[0])
        to_int = true
      else
        n = Integer(args[0])
        to_int = true if n < 1
      end
    when 2
      n = Integer(args[0])
      sw = args[1].is_a?(Hash) ? BigDecimal.__rounding_option(args[1]) : BigDecimal.__check_rounding_mode(args[1])
    else
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..2)"
    end
    r = __round_mode_for(n, sw)
    to_int ? r.to_i : r
  end

  def __trunc_like(args, mode)
    raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..1)" if args.size > 1
    n = args.empty? ? 0 : Integer(args[0])
    r = __round_mode_for(n, mode)
    args.empty? ? r.to_i : r
  end
  private :__trunc_like

  def truncate(*args) = __trunc_like(args, ROUND_DOWN)
  def floor(*args) = __trunc_like(args, ROUND_FLOOR)
  def ceil(*args) = __trunc_like(args, ROUND_CEILING)

  def fix
    return self unless @kind == :finite
    __round_at(0, ROUND_DOWN)
  end

  def frac
    return self unless @kind == :finite
    return BigDecimal.__zero(@sign) if @e >= 0
    m = @c % 10**(-@e)
    m == 0 ? BigDecimal.__zero(@sign) : BigDecimal.__make(:finite, @sign, m, @e)
  end

  # self * 10**i, exactly
  def _decimal_shift(i)
    i = Integer(i)
    return self unless @kind == :finite
    BigDecimal.__make(:finite, @sign, @c, @e + i)
  end

  # ---- comparison -----------------------------------------------------------------

  def <=>(other)
    unless __coercible?(other)
      return (other.respond_to?(:coerce) ? (begin; a, b = other.coerce(self); a <=> b; rescue StandardError; nil; end) : nil)
    end
    b = __operand!(other)
    return nil if @kind == :nan || b.__kind == :nan
    __cmp(b)
  end

  def __cmp(b)
    av = __rank
    bv = b.__rank
    return av <=> bv if av != bv
    return 0 if @kind == :inf || @kind == :zero
    # magnitudes differ in the leading digit's place before any alignment
    am = __msd
    bm = b.__msd
    return (am <=> bm) * @sign if am != bm
    e = [@e, b.__e].min
    (@sign * @c * 10**(@e - e)) <=> (b.__sign * b.__c * 10**(b.__e - e))
  end
  protected :__cmp

  # -2: -Infinity, -1: negative, 0: zero, 1: positive, 2: +Infinity
  def __rank
    case @kind
    when :inf then 2 * @sign
    when :zero then 0
    else @sign
    end
  end
  protected :__rank

  def ==(other)
    unless __coercible?(other)
      return false unless other.respond_to?(:coerce)
      begin
        a, b = other.coerce(self)
        return a == b
      rescue StandardError
        return false
      end
    end
    b = __operand!(other)
    return false if @kind == :nan || b.__kind == :nan
    __cmp(b) == 0
  end
  alias === ==
  alias eql? ==

  def __relop(other, op)
    unless __coercible?(other)
      begin
        raise NoMethodError unless other.respond_to?(:coerce)
        a, b = other.coerce(self)
      rescue StandardError
        raise ArgumentError, "comparison of BigDecimal with #{__cname(other)} failed"
      end
      return a.public_send(op, b)
    end
    b = __operand!(other)
    return false if @kind == :nan || b.__kind == :nan
    __cmp(b).public_send(op, 0)
  end
  private :__relop

  def <(other) = __relop(other, :<)
  def <=(other) = __relop(other, :<=)
  def >(other) = __relop(other, :>)
  def >=(other) = __relop(other, :>=)

  INFINITY = __make(:inf, 1)
  NAN = __make(:nan, 0)
end

module Kernel
  def BigDecimal(val, digs = nil, exception: true)
    unless digs.nil?
      digs = Integer(digs)
      if digs < 0
        return nil unless exception
        raise ArgumentError, "negative precision"
      end
    end
    BigDecimal.__convert(val, digs, exception)
  end
  module_function :BigDecimal
end
