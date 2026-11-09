# lib/logger_ext.rb -- ruby's own Logger (the logger gem 1.7.0 that ruby 4.0.9
# bundles; Ruby's license / BSD-2-Clause), its six files in one, in the order
# logger.rb requires them. Shipped by tools/gen_pathname_lib.rb as `logger`.
# It replaced mere-ruby's own smaller Logger, which had no log rotation and
# took `level: :info` as it was given.
# frozen_string_literal: true
# logger.rb - simple logging utility
# Copyright (C) 2000-2003, 2005, 2008, 2011  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.
#
# Documentation:: NAKAMURA, Hiroshi and Gavin Sinclair
# License::
#   You can redistribute it and/or modify it under the same terms of Ruby's
#   license; either the dual license version in 2003, or any later version.
# Revision:: $Id$
#
# A simple system for logging messages.  See Logger for more documentation.

require 'fiber'
require 'monitor'
require 'rbconfig'


class Logger
  VERSION = "1.7.0"
end

class Logger
  # Default formatter for log messages.
  class Formatter
    Format = "%.1s, [%s #%d] %5s -- %s: %s\n"
    DatetimeFormat = "%Y-%m-%dT%H:%M:%S.%6N"

    attr_accessor :datetime_format

    def initialize
      @datetime_format = nil
    end

    def call(severity, time, progname, msg)
      sprintf(Format, severity, format_datetime(time), Process.pid, severity, progname, msg2str(msg))
    end

  private

    def format_datetime(time)
      time.strftime(@datetime_format || DatetimeFormat)
    end

    def msg2str(msg)
      case msg
      when ::String
        msg
      when ::Exception
        "#{ msg.message } (#{ msg.class })\n#{ msg.backtrace.join("\n") if msg.backtrace }"
      else
        msg.inspect
      end
    end
  end
end


class Logger
  module Period
    module_function

    SiD = 24 * 60 * 60

    def next_rotate_time(now, shift_age)
      case shift_age
      when 'daily', :daily
        t = Time.mktime(now.year, now.month, now.mday) + SiD
      when 'weekly', :weekly
        t = Time.mktime(now.year, now.month, now.mday) + SiD * (7 - now.wday)
      when 'monthly', :monthly
        t = Time.mktime(now.year, now.month, 1) + SiD * 32
        return Time.mktime(t.year, t.month, 1)
      when 'now', 'everytime', :now, :everytime
        return now
      else
        raise ArgumentError, "invalid :shift_age #{shift_age.inspect}, should be daily, weekly, monthly, or everytime"
      end
      if t.hour.nonzero? or t.min.nonzero? or t.sec.nonzero?
        hour = t.hour
        t = Time.mktime(t.year, t.month, t.mday)
        t += SiD if hour > 12
      end
      t
    end

    def previous_period_end(now, shift_age)
      case shift_age
      when 'daily', :daily
        t = Time.mktime(now.year, now.month, now.mday) - SiD / 2
      when 'weekly', :weekly
        t = Time.mktime(now.year, now.month, now.mday) - (SiD * now.wday + SiD / 2)
      when 'monthly', :monthly
        t = Time.mktime(now.year, now.month, 1) - SiD / 2
      when 'now', 'everytime', :now, :everytime
        return now
      else
        raise ArgumentError, "invalid :shift_age #{shift_age.inspect}, should be daily, weekly, monthly, or everytime"
      end
      Time.mktime(t.year, t.month, t.mday, 23, 59, 59)
    end
  end
end

class Logger
  # Device used for logging messages.
  class LogDevice
    include Period

    attr_reader :dev
    attr_reader :filename
    include MonitorMixin

    def initialize(
      log = nil, shift_age: nil, shift_size: nil, shift_period_suffix: nil,
      binmode: false, reraise_write_errors: [], skip_header: false
    )
      @dev = @filename = @shift_age = @shift_size = @shift_period_suffix = nil
      @binmode = binmode
      @reraise_write_errors = reraise_write_errors
      @skip_header = skip_header
      mon_initialize
      set_dev(log)
      set_file(shift_age, shift_size, shift_period_suffix) if @filename
    end

    def write(message)
      handle_write_errors("writing") do
        synchronize do
          if @shift_age and @dev.respond_to?(:stat)
            handle_write_errors("shifting") {check_shift_log}
          end
          handle_write_errors("writing") {@dev.write(message)}
        end
      end
    end

    def close
      begin
        synchronize do
          @dev.close rescue nil
        end
      rescue Exception
        @dev.close rescue nil
      end
    end

    def reopen(log = nil, shift_age: nil, shift_size: nil, shift_period_suffix: nil, binmode: nil)
      # reopen the same filename if no argument, do nothing for IO
      log ||= @filename if @filename
      @binmode = binmode unless binmode.nil?
      if log
        synchronize do
          if @filename and @dev
            @dev.close rescue nil # close only file opened by Logger
            @filename = nil
          end
          set_dev(log)
          set_file(shift_age, shift_size, shift_period_suffix) if @filename
        end
      end
      self
    end

  private

    # :stopdoc:

    MODE = File::WRONLY | File::APPEND
    # TruffleRuby < 24.2 does not have File::SHARE_DELETE
    if File.const_defined? :SHARE_DELETE
      MODE_TO_OPEN = MODE | File::SHARE_DELETE | File::BINARY
    else
      MODE_TO_OPEN = MODE | File::BINARY
    end
    MODE_TO_CREATE = MODE_TO_OPEN | File::CREAT | File::EXCL

    def set_dev(log)
      if log.respond_to?(:write) and log.respond_to?(:close)
        @dev = log
        if log.respond_to?(:path) and path = log.path
          if File.exist?(path)
            @filename = path
          end
        end
      else
        @dev = open_logfile(log)
        @filename = log
      end
    end

    def set_file(shift_age, shift_size, shift_period_suffix)
      @shift_age = shift_age || @shift_age || 7
      @shift_size = shift_size || @shift_size || 1048576
      @shift_period_suffix = shift_period_suffix || @shift_period_suffix || '%Y%m%d'

      unless @shift_age.is_a?(Integer)
        base_time = @dev.respond_to?(:stat) ? @dev.stat.mtime : Time.now
        @next_rotate_time = next_rotate_time(base_time, @shift_age)
      end
    end

    if MODE_TO_OPEN == MODE
      def fixup_mode(dev)
        dev
      end
    else
      def fixup_mode(dev)
        return dev if @binmode
        dev.autoclose = false
        old_dev = dev
        dev = File.new(dev.fileno, mode: MODE, path: dev.path)
        old_dev.close
        PathAttr.set_path(dev, filename) if defined?(PathAttr)
        dev
      end
    end

    def open_logfile(filename)
      begin
        dev = File.open(filename, MODE_TO_OPEN)
      rescue Errno::ENOENT
        create_logfile(filename)
      else
        dev = fixup_mode(dev)
        dev.sync = true
        dev.binmode if @binmode
        dev
      end
    end

    def create_logfile(filename)
      begin
        logdev = File.open(filename, MODE_TO_CREATE)
        logdev.flock(File::LOCK_EX)
        logdev = fixup_mode(logdev)
        logdev.sync = true
        logdev.binmode if @binmode
        add_log_header(logdev) unless @skip_header
        logdev.flock(File::LOCK_UN)
        logdev
      rescue Errno::EEXIST
        # file is created by another process
        open_logfile(filename)
      end
    end

    def handle_write_errors(mesg)
      yield
    rescue *@reraise_write_errors
      raise
    rescue
      warn("log #{mesg} failed. #{$!}")
    end

    def add_log_header(file)
      file.write(
        "# Logfile created on %s by %s\n" % [Time.now.to_s, Logger::ProgName]
      ) if file.size == 0
    end

    def check_shift_log
      if @shift_age.is_a?(Integer)
        # Note: always returns false if '0'.
        if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)
          lock_shift_log { shift_log_age }
        end
      else
        now = Time.now
        if now >= @next_rotate_time
          @next_rotate_time = next_rotate_time(now, @shift_age)
          lock_shift_log { shift_log_period(previous_period_end(now, @shift_age)) }
        end
      end
    end

    def lock_shift_log
      retry_limit = 8
      retry_sleep = 0.1
      begin
        File.open(@filename, MODE_TO_OPEN) do |lock|
          lock.flock(File::LOCK_EX) # inter-process locking. will be unlocked at closing file
          if File.identical?(@filename, lock) and File.identical?(lock, @dev)
            yield # log shifting
          else
            # log shifted by another process (i-node before locking and i-node after locking are different)
            @dev.close rescue nil
            @dev = open_logfile(@filename)
          end
        end
        true
      rescue Errno::ENOENT
        # @filename file would not exist right after #rename and before #create_logfile
        if retry_limit <= 0
          warn("log rotation inter-process lock failed. #{$!}")
        else
          sleep retry_sleep
          retry_limit -= 1
          retry_sleep *= 2
          retry
        end
      end
    rescue
      warn("log rotation inter-process lock failed. #{$!}")
    end

    def shift_log_age
      (@shift_age-3).downto(0) do |i|
        if FileTest.exist?("#{@filename}.#{i}")
          File.rename("#{@filename}.#{i}", "#{@filename}.#{i+1}")
        end
      end
      shift_log_file("#{@filename}.0")
    end

    def shift_log_period(period_end)
      suffix = period_end.strftime(@shift_period_suffix)
      age_file = "#{@filename}.#{suffix}"
      if FileTest.exist?(age_file)
        # try to avoid filename crash caused by Timestamp change.
        idx = 0
        # .99 can be overridden; avoid too much file search with 'loop do'
        while idx < 100
          idx += 1
          age_file = "#{@filename}.#{suffix}.#{idx}"
          break unless FileTest.exist?(age_file)
        end
      end
      shift_log_file(age_file)
    end

    def shift_log_file(shifted)
      stat = @dev.stat
      @dev.close rescue nil
      File.rename(@filename, shifted)
      @dev = create_logfile(@filename)
      mode, uid, gid = stat.mode, stat.uid, stat.gid
      begin
        @dev.chmod(mode) if mode
        mode = nil
        @dev.chown(uid, gid)
      rescue Errno::EPERM
        if mode
          # failed to chmod, probably nothing can do more.
        elsif uid
          uid = nil
          retry # to change gid only
        end
      end
      return true
    end
  end
end

# (mere-ruby: log_device.rb probes whether File.new(fd, path:) keeps a path by
#  opening its own __FILE__ -- a file the shipped library does not have. Its
#  fallback is what is defined here, unconditionally.)
module PathAttr               # :nodoc:
  attr_reader :path

  def self.set_path(file, path)
    file.extend(self).instance_variable_set(:@path, path)
  end
end

class Logger
  # Logging severity.
  module Severity
    # Low-level information, mostly for developers.
    DEBUG = 0
    # Generic (useful) information about system operation.
    INFO = 1
    # A warning.
    WARN = 2
    # A handleable error condition.
    ERROR = 3
    # An unhandleable error that results in a program crash.
    FATAL = 4
    # An unknown message that should always be logged.
    UNKNOWN = 5

    LEVELS = {
      "debug" => DEBUG,
      "info" => INFO,
      "warn" => WARN,
      "error" => ERROR,
      "fatal" => FATAL,
      "unknown" => UNKNOWN,
    }
    private_constant :LEVELS

    def self.coerce(severity)
      if severity.is_a?(Integer)
        severity
      else
        key = severity.to_s.downcase
        LEVELS[key] || raise(ArgumentError, "invalid log level: #{severity}")
      end
    end
  end
end

class Logger
  # not used after 1.2.7. just for compat.
  class Error < RuntimeError # :nodoc:
  end
  class ShiftingError < Error # :nodoc:
  end
end

# \Class \Logger provides a simple but sophisticated logging utility that
# you can use to create one or more
# {event logs}[https://en.wikipedia.org/wiki/Logging_(software)#Event_logs]
# for your program.
# Each such log contains a chronological sequence of entries
# that provides a record of the program's activities.
#
# == About the Examples
#
# All examples on this page assume that \Logger has been required:
#
#   require 'logger'
#
# == Synopsis
#
# Create a log with Logger.new:
#
#   # Single log file.
#   logger = Logger.new('t.log')
#   # Size-based rotated logging: 3 10-megabyte files.
#   logger = Logger.new('t.log', 3, 10485760)
#   # Period-based rotated logging: daily (also allowed: 'weekly', 'monthly').
#   logger = Logger.new('t.log', 'daily')
#   # Log to an IO stream.
#   logger = Logger.new($stdout)
#
# Add entries (level, message) with Logger#add:
#
#   logger.add(Logger::DEBUG, 'Maximal debugging info')
#   logger.add(Logger::INFO, 'Non-error information')
#   logger.add(Logger::WARN, 'Non-error warning')
#   logger.add(Logger::ERROR, 'Non-fatal error')
#   logger.add(Logger::FATAL, 'Fatal error')
#   logger.add(Logger::UNKNOWN, 'Most severe')
#
# Close the log with Logger#close:
#
#   logger.close
#
# == Entries
#
# You can add entries with method Logger#add:
#
#   logger.add(Logger::DEBUG, 'Maximal debugging info')
#   logger.add(Logger::INFO, 'Non-error information')
#   logger.add(Logger::WARN, 'Non-error warning')
#   logger.add(Logger::ERROR, 'Non-fatal error')
#   logger.add(Logger::FATAL, 'Fatal error')
#   logger.add(Logger::UNKNOWN, 'Most severe')
#
# These shorthand methods also add entries:
#
#   logger.debug('Maximal debugging info')
#   logger.info('Non-error information')
#   logger.warn('Non-error warning')
#   logger.error('Non-fatal error')
#   logger.fatal('Fatal error')
#   logger.unknown('Most severe')
#
# When you call any of these methods,
# the entry may or may not be written to the log,
# depending on the entry's severity and on the log level;
# see {Log Level}[rdoc-ref:Logger@Log+Level]
#
# An entry always has:
#
# - A severity (the required argument to #add).
# - An automatically created timestamp.
#
# And may also have:
#
# - A message.
# - A program name.
#
# Example:
#
#   logger = Logger.new($stdout)
#   logger.add(Logger::INFO, 'My message.', 'mung')
#   # => I, [2022-05-07T17:21:46.536234 #20536]  INFO -- mung: My message.
#
# The default format for an entry is:
#
#   "%s, [%s #%d] %5s -- %s: %s\n"
#
# where the values to be formatted are:
#
# - \Severity (one letter).
# - Timestamp.
# - Process id.
# - \Severity (word).
# - Program name.
# - Message.
#
# You can use a different entry format by:
#
# - Setting a custom format proc (affects following entries);
#   see {formatter=}[Logger.html#attribute-i-formatter].
# - Calling any of the methods above with a block
#   (affects only the one entry).
#   Doing so can have two benefits:
#
#   - Context: the block can evaluate the entire program context
#     and create a context-dependent message.
#   - Performance: the block is not evaluated unless the log level
#     permits the entry actually to be written:
#
#       logger.error { my_slow_message_generator }
#
#     Contrast this with the string form, where the string is
#     always evaluated, regardless of the log level:
#
#       logger.error("#{my_slow_message_generator}")
#
# === \Severity
#
# The severity of a log entry has two effects:
#
# - Determines whether the entry is selected for inclusion in the log;
#   see {Log Level}[rdoc-ref:Logger@Log+Level].
# - Indicates to any log reader (whether a person or a program)
#   the relative importance of the entry.
#
# === Timestamp
#
# The timestamp for a log entry is generated automatically
# when the entry is created.
#
# The logged timestamp is formatted by method
# {Time#strftime}[https://docs.ruby-lang.org/en/master/Time.html#method-i-strftime]
# using this format string:
#
#   '%Y-%m-%dT%H:%M:%S.%6N'
#
# Example:
#
#   logger = Logger.new($stdout)
#   logger.add(Logger::INFO)
#   # => I, [2022-05-07T17:04:32.318331 #20536]  INFO -- : nil
#
# You can set a different format using method #datetime_format=.
#
# === Message
#
# The message is an optional argument to an entry method:
#
#   logger = Logger.new($stdout)
#   logger.add(Logger::INFO, 'My message')
#   # => I, [2022-05-07T18:15:37.647581 #20536]  INFO -- : My message
#
# For the default entry formatter, <tt>Logger::Formatter</tt>,
# the message object may be:
#
# - A string: used as-is.
# - An Exception: <tt>message.message</tt> is used.
# - Anything else: <tt>message.inspect</tt> is used.
#
# *Note*: Logger::Formatter does not escape or sanitize
# the message passed to it.
# Developers should be aware that malicious data (user input)
# may be in the message, and should explicitly escape untrusted data.
#
# You can use a custom formatter to escape message data;
# see the example at {formatter=}[Logger.html#attribute-i-formatter].
#
# === Program Name
#
# The program name is an optional argument to an entry method:
#
#   logger = Logger.new($stdout)
#   logger.add(Logger::INFO, 'My message', 'mung')
#   # => I, [2022-05-07T18:17:38.084716 #20536]  INFO -- mung: My message
#
# The default program name for a new logger may be set in the call to
# Logger.new via optional keyword argument +progname+:
#
#   logger = Logger.new('t.log', progname: 'mung')
#
# The default program name for an existing logger may be set
# by a call to method #progname=:
#
#   logger.progname = 'mung'
#
# The current program name may be retrieved with method
# {progname}[Logger.html#attribute-i-progname]:
#
#   logger.progname # => "mung"
#
# == Log Level
#
# The log level setting determines whether an entry is actually
# written to the log, based on the entry's severity.
#
# These are the defined severities (least severe to most severe):
#
#   logger = Logger.new($stdout)
#   logger.add(Logger::DEBUG, 'Maximal debugging info')
#   # => D, [2022-05-07T17:57:41.776220 #20536] DEBUG -- : Maximal debugging info
#   logger.add(Logger::INFO, 'Non-error information')
#   # => I, [2022-05-07T17:59:14.349167 #20536]  INFO -- : Non-error information
#   logger.add(Logger::WARN, 'Non-error warning')
#   # => W, [2022-05-07T18:00:45.337538 #20536]  WARN -- : Non-error warning
#   logger.add(Logger::ERROR, 'Non-fatal error')
#   # => E, [2022-05-07T18:02:41.592912 #20536] ERROR -- : Non-fatal error
#   logger.add(Logger::FATAL, 'Fatal error')
#   # => F, [2022-05-07T18:05:24.703931 #20536] FATAL -- : Fatal error
#   logger.add(Logger::UNKNOWN, 'Most severe')
#   # => A, [2022-05-07T18:07:54.657491 #20536]   ANY -- : Most severe
#
# The default initial level setting is Logger::DEBUG, the lowest level,
# which means that all entries are to be written, regardless of severity:
#
#   logger = Logger.new($stdout)
#   logger.level # => 0
#   logger.add(0, "My message")
#   # => D, [2022-05-11T15:10:59.773668 #20536] DEBUG -- : My message
#
# You can specify a different setting in a new logger
# using keyword argument +level+ with an appropriate value:
#
#   logger = Logger.new($stdout, level: Logger::ERROR)
#   logger = Logger.new($stdout, level: 'error')
#   logger = Logger.new($stdout, level: :error)
#   logger.level # => 3
#
# With this level, entries with severity Logger::ERROR and higher
# are written, while those with lower severities are not written:
#
#   logger = Logger.new($stdout, level: Logger::ERROR)
#   logger.add(3)
#   # => E, [2022-05-11T15:17:20.933362 #20536] ERROR -- : nil
#   logger.add(2) # Silent.
#
# You can set the log level for an existing logger
# with method #level=:
#
#   logger.level = Logger::ERROR
#
# These shorthand methods also set the level:
#
#   logger.debug! # => 0
#   logger.info!  # => 1
#   logger.warn!  # => 2
#   logger.error! # => 3
#   logger.fatal! # => 4
#
# You can retrieve the log level with method #level.
#
#   logger.level = Logger::ERROR
#   logger.level # => 3
#
# These methods return whether a given
# level is to be written:
#
#   logger.level = Logger::ERROR
#   logger.debug? # => false
#   logger.info?  # => false
#   logger.warn?  # => false
#   logger.error? # => true
#   logger.fatal? # => true
#
# == Log File Rotation
#
# By default, a log file is a single file that grows indefinitely
# (until explicitly closed); there is no file rotation.
#
# To keep log files to a manageable size,
# you can use _log_ _file_ _rotation_, which uses multiple log files:
#
# - Each log file has entries for a non-overlapping
#   time interval.
# - Only the most recent log file is open and active;
#   the others are closed and inactive.
#
# === Size-Based Rotation
#
# For size-based log file rotation, call Logger.new with:
#
# - Argument +logdev+ as a file path.
# - Argument +shift_age+ with a positive integer:
#   the number of log files to be in the rotation.
# - Argument +shift_size+ as a positive integer:
#   the maximum size (in bytes) of each log file;
#   defaults to 1048576 (1 megabyte).
#
# Examples:
#
#   logger = Logger.new('t.log', 3)           # Three 1-megabyte files.
#   logger = Logger.new('t.log', 5, 10485760) # Five 10-megabyte files.
#
# For these examples, suppose:
#
#   logger = Logger.new('t.log', 3)
#
# Logging begins in the new log file, +t.log+;
# the log file is "full" and ready for rotation
# when a new entry would cause its size to exceed +shift_size+.
#
# The first time +t.log+ is full:
#
# - +t.log+ is closed and renamed to +t.log.0+.
# - A new file +t.log+ is opened.
#
# The second time +t.log+ is full:
#
# - +t.log.0 is renamed as +t.log.1+.
# - +t.log+ is closed and renamed to +t.log.0+.
# - A new file +t.log+ is opened.
#
# Each subsequent time that +t.log+ is full,
# the log files are rotated:
#
# - +t.log.1+ is removed.
# - +t.log.0 is renamed as +t.log.1+.
# - +t.log+ is closed and renamed to +t.log.0+.
# - A new file +t.log+ is opened.
#
# === Periodic Rotation
#
# For periodic rotation, call Logger.new with:
#
# - Argument +logdev+ as a file path.
# - Argument +shift_age+ as a string period indicator.
#
# Examples:
#
#   logger = Logger.new('t.log', 'daily')   # Rotate log files daily.
#   logger = Logger.new('t.log', 'weekly')  # Rotate log files weekly.
#   logger = Logger.new('t.log', 'monthly') # Rotate log files monthly.
#
# Example:
#
#   logger = Logger.new('t.log', 'daily')
#
# When the given period expires:
#
# - The base log file, +t.log+ is closed and renamed
#   with a date-based suffix such as +t.log.20220509+.
# - A new log file +t.log+ is opened.
# - Nothing is removed.
#
# The default format for the suffix is <tt>'%Y%m%d'</tt>,
# which produces a suffix similar to the one above.
# You can set a different format using create-time option
# +shift_period_suffix+;
# see details and suggestions at
# {Time#strftime}[https://docs.ruby-lang.org/en/master/Time.html#method-i-strftime].
#
class Logger
  _, name, rev = %w$Id$
  if name
    name = name.chomp(",v")
  else
    name = File.basename(__FILE__)
  end
  rev ||= "v#{VERSION}"
  ProgName = "#{name}/#{rev}"

  include Severity

  # Logging severity threshold (e.g. <tt>Logger::INFO</tt>).
  def level
    level_override[level_key] || @level
  end

  # Sets the log level; returns +severity+.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  # Argument +severity+ may be an integer, a string, or a symbol:
  #
  #   logger.level = Logger::ERROR # => 3
  #   logger.level = 3             # => 3
  #   logger.level = 'error'       # => "error"
  #   logger.level = :error        # => :error
  #
  # Logger#sev_threshold= is an alias for Logger#level=.
  #
  def level=(severity)
    @level = Severity.coerce(severity)
  end

  # Adjust the log level during the block execution for the current Fiber only
  #
  #   logger.with_level(:debug) do
  #     logger.debug { "Hello" }
  #   end
  def with_level(severity)
    prev, level_override[level_key] = level, Severity.coerce(severity)
    begin
      yield
    ensure
      if prev
        level_override[level_key] = prev
      else
        level_override.delete(level_key)
      end
    end
  end

  # Program name to include in log messages.
  attr_accessor :progname

  # Sets the date-time format.
  #
  # Argument +datetime_format+ should be either of these:
  #
  # - A string suitable for use as a format for method
  #   {Time#strftime}[https://docs.ruby-lang.org/en/master/Time.html#method-i-strftime].
  # - +nil+: the logger uses <tt>'%Y-%m-%dT%H:%M:%S.%6N'</tt>.
  #
  def datetime_format=(datetime_format)
    @default_formatter.datetime_format = datetime_format
  end

  # Returns the date-time format; see #datetime_format=.
  #
  def datetime_format
    @default_formatter.datetime_format
  end

  # Sets or retrieves the logger entry formatter proc.
  #
  # When +formatter+ is +nil+, the logger uses Logger::Formatter.
  #
  # When +formatter+ is a proc, a new entry is formatted by the proc,
  # which is called with four arguments:
  #
  # - +severity+: The severity of the entry.
  # - +time+: A Time object representing the entry's timestamp.
  # - +progname+: The program name for the entry.
  # - +msg+: The message for the entry (string or string-convertible object).
  #
  # The proc should return a string containing the formatted entry.
  #
  # This custom formatter uses
  # {String#dump}[https://docs.ruby-lang.org/en/master/String.html#method-i-dump]
  # to escape the message string:
  #
  #   logger = Logger.new($stdout, progname: 'mung')
  #   original_formatter = logger.formatter || Logger::Formatter.new
  #   logger.formatter = proc { |severity, time, progname, msg|
  #     original_formatter.call(severity, time, progname, msg.dump)
  #   }
  #   logger.add(Logger::INFO, "hello \n ''")
  #   logger.add(Logger::INFO, "\f\x00\xff\\\"")
  #
  # Output:
  #
  #   I, [2022-05-13T13:16:29.637488 #8492]  INFO -- mung: "hello \n ''"
  #   I, [2022-05-13T13:16:29.637610 #8492]  INFO -- mung: "\f\x00\xFF\\\""
  #
  attr_accessor :formatter

  alias sev_threshold level
  alias sev_threshold= level=

  # Returns +true+ if the log level allows entries with severity
  # Logger::DEBUG to be written, +false+ otherwise.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def debug?; level <= DEBUG; end

  # Sets the log level to Logger::DEBUG.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def debug!; self.level = DEBUG; end

  # Returns +true+ if the log level allows entries with severity
  # Logger::INFO to be written, +false+ otherwise.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def info?; level <= INFO; end

  # Sets the log level to Logger::INFO.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def info!; self.level = INFO; end

  # Returns +true+ if the log level allows entries with severity
  # Logger::WARN to be written, +false+ otherwise.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def warn?; level <= WARN; end

  # Sets the log level to Logger::WARN.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def warn!; self.level = WARN; end

  # Returns +true+ if the log level allows entries with severity
  # Logger::ERROR to be written, +false+ otherwise.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def error?; level <= ERROR; end

  # Sets the log level to Logger::ERROR.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def error!; self.level = ERROR; end

  # Returns +true+ if the log level allows entries with severity
  # Logger::FATAL to be written, +false+ otherwise.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def fatal?; level <= FATAL; end

  # Sets the log level to Logger::FATAL.
  # See {Log Level}[rdoc-ref:Logger@Log+Level].
  #
  def fatal!; self.level = FATAL; end

  # :call-seq:
  #    Logger.new(logdev, shift_age = 0, shift_size = 1048576, **options)
  #
  # With the single argument +logdev+,
  # returns a new logger with all default options:
  #
  #   Logger.new('t.log') # => #<Logger:0x000001e685dc6ac8>
  #
  # Argument +logdev+ must be one of:
  #
  # - A string filepath: entries are to be written
  #   to the file at that path; if the file at that path exists,
  #   new entries are appended.
  # - An IO stream (typically <tt>$stdout</tt>, <tt>$stderr</tt>. or
  #   an open file): entries are to be written to the given stream.
  # - +nil+ or +File::NULL+: no entries are to be written.
  #
  # Argument +shift_age+ must be one of:
  #
  # - The number of log files to be in the rotation.
  #   See {Size-Based Rotation}[rdoc-ref:Logger@Size-Based+Rotation].
  # - A string period indicator.
  #   See {Periodic Rotation}[rdoc-ref:Logger@Periodic+Rotation].
  #
  # Argument +shift_size+ is the maximum size (in bytes) of each log file.
  # See {Size-Based Rotation}[rdoc-ref:Logger@Size-Based+Rotation].
  #
  # Examples:
  #
  #   Logger.new('t.log')
  #   Logger.new($stdout)
  #
  # The keyword options are:
  #
  # - +level+: sets the log level; default value is Logger::DEBUG.
  #   See {Log Level}[rdoc-ref:Logger@Log+Level]:
  #
  #     Logger.new('t.log', level: Logger::ERROR)
  #
  # - +progname+: sets the default program name; default is +nil+.
  #   See {Program Name}[rdoc-ref:Logger@Program+Name]:
  #
  #     Logger.new('t.log', progname: 'mung')
  #
  # - +formatter+: sets the entry formatter; default is +nil+.
  #   See {formatter=}[Logger.html#attribute-i-formatter].
  #
  # - +datetime_format+: sets the format for entry timestamp;
  #   default is +nil+.
  #   See #datetime_format=.
  #
  # - +binmode+: sets whether the logger writes in binary mode;
  #   default is +false+.
  #
  # - +shift_period_suffix+: sets the format for the filename suffix
  #   for periodic log file rotation; default is <tt>'%Y%m%d'</tt>.
  #   See {Periodic Rotation}[rdoc-ref:Logger@Periodic+Rotation].
  #
  # - +reraise_write_errors+: An array of exception classes, which will
  #   be reraised if there is an error when writing to the log device.
  #   The default is to swallow all exceptions raised.
  # - +skip_header+: If +true+, prevents the logger from writing a header
  #   when creating a new log file. The default is +false+, meaning
  #   the header will be written as usual.
  #
  def initialize(logdev, shift_age = 0, shift_size = 1048576, level: DEBUG,
                 progname: nil, formatter: nil, datetime_format: nil,
                 binmode: false, shift_period_suffix: '%Y%m%d',
                 reraise_write_errors: [], skip_header: false)
    self.level = level
    self.progname = progname
    @default_formatter = Formatter.new
    self.datetime_format = datetime_format
    self.formatter = formatter
    @logdev = nil
    @level_override = {}
    if logdev && logdev != File::NULL
      @logdev = LogDevice.new(logdev, shift_age: shift_age,
        shift_size: shift_size,
        shift_period_suffix: shift_period_suffix,
        binmode: binmode,
        reraise_write_errors: reraise_write_errors,
        skip_header: skip_header)
    end
  end

  # Sets the logger's output stream:
  #
  # - If +logdev+ is +nil+, reopens the current output stream.
  # - If +logdev+ is a filepath, opens the indicated file for append.
  # - If +logdev+ is an IO stream
  #   (usually <tt>$stdout</tt>, <tt>$stderr</tt>, or an open File object),
  #   opens the stream for append.
  #
  # Example:
  #
  #   logger = Logger.new('t.log')
  #   logger.add(Logger::ERROR, 'one')
  #   logger.close
  #   logger.add(Logger::ERROR, 'two') # Prints 'log writing failed. closed stream'
  #   logger.reopen
  #   logger.add(Logger::ERROR, 'three')
  #   logger.close
  #   File.readlines('t.log')
  #   # =>
  #   # ["# Logfile created on 2022-05-12 14:21:19 -0500 by logger.rb/v1.5.0\n",
  #   #  "E, [2022-05-12T14:21:27.596726 #22428] ERROR -- : one\n",
  #   #  "E, [2022-05-12T14:23:05.847241 #22428] ERROR -- : three\n"]
  #
  def reopen(logdev = nil, shift_age = nil, shift_size = nil, shift_period_suffix: nil, binmode: nil)
    @logdev&.reopen(logdev, shift_age: shift_age, shift_size: shift_size,
                    shift_period_suffix: shift_period_suffix, binmode: binmode)
    self
  end

  # Creates a log entry, which may or may not be written to the log,
  # depending on the entry's severity and on the log level.
  # See {Log Level}[rdoc-ref:Logger@Log+Level]
  # and {Entries}[rdoc-ref:Logger@Entries] for details.
  #
  # Examples:
  #
  #   logger = Logger.new($stdout, progname: 'mung')
  #   logger.add(Logger::INFO)
  #   logger.add(Logger::ERROR, 'No good')
  #   logger.add(Logger::ERROR, 'No good', 'gnum')
  #
  # Output:
  #
  #   I, [2022-05-12T16:25:31.469726 #36328]  INFO -- mung: mung
  #   E, [2022-05-12T16:25:55.349414 #36328] ERROR -- mung: No good
  #   E, [2022-05-12T16:26:35.841134 #36328] ERROR -- gnum: No good
  #
  # These convenience methods have implicit severity:
  #
  # - #debug.
  # - #info.
  # - #warn.
  # - #error.
  # - #fatal.
  # - #unknown.
  #
  def add(severity, message = nil, progname = nil)
    severity ||= UNKNOWN
    if @logdev.nil? or severity < level
      return true
    end
    if progname.nil?
      progname = @progname
    end
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    @logdev.write(
      format_message(format_severity(severity), Time.now, progname, message))
    true
  end
  alias log add

  # Writes the given +msg+ to the log with no formatting;
  # returns the number of characters written,
  # or +nil+ if no log device exists:
  #
  #   logger = Logger.new($stdout)
  #   logger << 'My message.' # => 10
  #
  # Output:
  #
  #   My message.
  #
  def <<(msg)
    @logdev&.write(msg)
  end

  # Equivalent to calling #add with severity <tt>Logger::DEBUG</tt>.
  #
  def debug(progname = nil, &block)
    add(DEBUG, nil, progname, &block)
  end

  # Equivalent to calling #add with severity <tt>Logger::INFO</tt>.
  #
  def info(progname = nil, &block)
    add(INFO, nil, progname, &block)
  end

  # Equivalent to calling #add with severity <tt>Logger::WARN</tt>.
  #
  def warn(progname = nil, &block)
    add(WARN, nil, progname, &block)
  end

  # Equivalent to calling #add with severity <tt>Logger::ERROR</tt>.
  #
  def error(progname = nil, &block)
    add(ERROR, nil, progname, &block)
  end

  # Equivalent to calling #add with severity <tt>Logger::FATAL</tt>.
  #
  def fatal(progname = nil, &block)
    add(FATAL, nil, progname, &block)
  end

  # Equivalent to calling #add with severity <tt>Logger::UNKNOWN</tt>.
  #
  def unknown(progname = nil, &block)
    add(UNKNOWN, nil, progname, &block)
  end

  # Closes the logger; returns +nil+:
  #
  #   logger = Logger.new('t.log')
  #   logger.close       # => nil
  #   logger.info('foo') # Prints "log writing failed. closed stream"
  #
  # Related: Logger#reopen.
  def close
    @logdev&.close
  end

private

  # \Severity label for logging (max 5 chars).
  SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY).freeze

  def format_severity(severity)
    SEV_LABEL[severity] || 'ANY'
  end

  # Guarantee the existence of this ivar even when subclasses don't call the superclass constructor.
  def level_override
    unless defined?(@level_override)
      bad = self.class.instance_method(:initialize)
      file, line = bad.source_location
      Kernel.warn <<~";;;", uplevel: 2
        Logger not initialized properly
        #{file}:#{line}: info: #{bad.owner}\##{bad.name}: \
        does not call super probably
      ;;;
    end
    @level_override ||= {}
  end

  def level_key
    Fiber.current
  end

  def format_message(severity, datetime, progname, msg)
    (@formatter || @default_formatter).call(severity, datetime, progname, msg)
  end
end
