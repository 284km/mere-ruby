# frozen_string_literal: true
#
# Syslog's C half, written in Ruby for mere-ruby.
#
# The reference's `require "syslog"` reads the gem's syslog.rb, which requires
# 'syslog_ext' -- the C extension (ext/syslog/syslog.c, syslog 0.3.0).
# mere-ruby cannot load a C extension, so this file is what 'syslog_ext' is
# here: the Syslog module, its constants and macros, and the state the C keeps
# in statics. openlog(3), syslog(3), closelog(3) and setlogmask(3) are the
# runtime's (Mere v0.1.677), reached through Syslog.__openlog and friends.
# syslog(3) takes a format and varargs, which no extern can pass; the runtime
# calls it with "%s" and the message, as syslog.c itself does.

module Syslog
  VERSION = "0.3.0"

  module Option
    LOG_PID = 0x01
    LOG_CONS = 0x02
    LOG_ODELAY = 0x04
    LOG_NDELAY = 0x08
    LOG_NOWAIT = 0x10
    LOG_PERROR = 0x20
  end

  # (the facilities both macOS and glibc define; syslog.c guards each one,
  # and neither has LOG_CONSOLE, LOG_NTP or LOG_SECURITY)
  module Facility
    LOG_KERN = 0 << 3
    LOG_USER = 1 << 3
    LOG_MAIL = 2 << 3
    LOG_DAEMON = 3 << 3
    LOG_AUTH = 4 << 3
    LOG_SYSLOG = 5 << 3
    LOG_LPR = 6 << 3
    LOG_NEWS = 7 << 3
    LOG_UUCP = 8 << 3
    LOG_CRON = 9 << 3
    LOG_AUTHPRIV = 10 << 3
    LOG_FTP = 11 << 3
    LOG_LOCAL0 = 16 << 3
    LOG_LOCAL1 = 17 << 3
    LOG_LOCAL2 = 18 << 3
    LOG_LOCAL3 = 19 << 3
    LOG_LOCAL4 = 20 << 3
    LOG_LOCAL5 = 21 << 3
    LOG_LOCAL6 = 22 << 3
    LOG_LOCAL7 = 23 << 3
  end

  module Level
    LOG_EMERG = 0
    LOG_ALERT = 1
    LOG_CRIT = 2
    LOG_ERR = 3
    LOG_WARNING = 4
    LOG_NOTICE = 5
    LOG_INFO = 6
    LOG_DEBUG = 7
  end

  # NUM2INT: an Integer, a Float truncated, or #to_int -- not a String
  def self.__num2int(v)
    return v if v.is_a?(Integer)
    return v.to_i if v.is_a?(Float)
    raise TypeError, "no implicit conversion from nil to integer" if v.nil?
    raise TypeError, "no implicit conversion of #{v == true || v == false ? v : v.class} into Integer" unless v.respond_to?(:to_int)
    v.to_int
  end

  module Macros
    def LOG_MASK(pri) = 1 << Syslog.__num2int(pri)
    def LOG_UPTO(pri) = (1 << (Syslog.__num2int(pri) + 1)) - 1

    def self.included(target)
      target.extend(Macros)
      self
    end
  end

  module Constants
    include Option
    include Facility
    include Level
    include Macros

    def self.included(target)
      target.extend(Macros)
      self
    end
  end

  include Constants

  # syslog.c's statics
  @__opened = false
  @__ident = nil
  @__options = -1
  @__facility = -1
  @__mask = -1

  module_function

  def __write(pri, args)
    raise ArgumentError, "no log message supplied" if args.empty?
    raise RuntimeError, "must open syslog before write" unless Syslog.__opened?
    Syslog.__syslog(pri, Kernel.format(*args))
  end

  def open(ident = nil, opt = nil, fac = nil)
    raise RuntimeError, "syslog already open" if Syslog.__opened?
    ident = $0 if ident.nil?
    ident = String.try_convert(ident) or raise TypeError, "no implicit conversion of #{ident.nil? ? 'nil' : ident.class} into String"
    raise ArgumentError, "string contains null byte" if ident.include?("\0")
    options = opt.nil? ? (LOG_PID | LOG_CONS) : Syslog.__num2int(opt)
    facility = fac.nil? ? LOG_USER : Syslog.__num2int(fac)
    Syslog.__openlog(ident, options, facility)
    Syslog.__set_state(true, ident.dup.freeze, options, facility)
    # setlogmask(syslog_mask = setlogmask(0))
    m = Syslog.__setlogmask(0)
    Syslog.__setlogmask(m)
    Syslog.__set_mask(m)
    if block_given?
      begin
        yield Syslog
      ensure
        Syslog.close
      end
    end
    Syslog
  end

  def reopen(*args, &block)
    Syslog.close
    Syslog.open(*args, &block)
  end

  alias open! reopen
  # (the singleton's alias as well: Syslog.method(:open!) == Syslog.method(:reopen))
  class << self
    alias open! reopen
  end

  def opened? = Syslog.__opened?

  def ident = Syslog.__opened? ? +Syslog.__state[0] : nil
  def options = Syslog.__opened? ? Syslog.__state[1] : nil
  def facility = Syslog.__opened? ? Syslog.__state[2] : nil
  def mask = Syslog.__opened? ? Syslog.__state[3] : nil

  def mask=(m)
    raise RuntimeError, "must open syslog before setting log mask" unless Syslog.__opened?
    v = Syslog.__num2int(m)
    Syslog.__setlogmask(v)
    Syslog.__set_mask(v)
    m
  end

  def close
    raise RuntimeError, "syslog not opened" unless Syslog.__opened?
    Syslog.__closelog
    Syslog.__set_state(false, nil, -1, -1)
    Syslog.__set_mask(-1)
    nil
  end

  def log(pri, *args)
    raise ArgumentError, "wrong number of arguments (given 1, expected 2+)" if args.empty?
    raise TypeError, "type mismatch: #{pri.class} given" unless pri.is_a?(Integer) && pri.bit_length < 63
    Syslog.__write(pri, args)
    Syslog
  end

  def emerg(*args) = (Syslog.__write(LOG_EMERG, args); Syslog)
  def alert(*args) = (Syslog.__write(LOG_ALERT, args); Syslog)
  def crit(*args) = (Syslog.__write(LOG_CRIT, args); Syslog)
  def err(*args) = (Syslog.__write(LOG_ERR, args); Syslog)
  def warning(*args) = (Syslog.__write(LOG_WARNING, args); Syslog)
  def notice(*args) = (Syslog.__write(LOG_NOTICE, args); Syslog)
  def info(*args) = (Syslog.__write(LOG_INFO, args); Syslog)
  def debug(*args) = (Syslog.__write(LOG_DEBUG, args); Syslog)

  def instance = Syslog

  class << self
    def inspect
      return "<##{self}: opened=false>" unless __opened?
      i, o, f, m = __state
      "<##{self}: opened=true, ident=\"#{i}\", options=#{o}, facility=#{f}, mask=#{m}>"
    end

    def __opened? = @__opened
    def __state = [@__ident, @__options, @__facility, @__mask]

    def __set_state(opened, ident, options, facility)
      @__opened = opened
      @__ident = ident
      @__options = options
      @__facility = facility
    end

    def __set_mask(m)
      @__mask = m
    end
  end
end
