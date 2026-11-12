require "stringio"

# io/console, as ruby's ext/io/console answers it, over a descriptor's
# termios and window size (Mere v0.1.724's tty_attrs / tty_set_attrs /
# tty_winsize / tty_set_winsize / tty_flush). The termios crosses as text --
# the four flag words, two speeds and the control characters in hex -- in
# the platform's own bits, which are this file's to know.

# io/console adds #getch to StringIO; it is exactly #getc. #getpass is NOT
# defined: its reading is not "a line without the newline" -- ruby consumes
# one character more than that, and a method that is close but not the same
# is a wrong answer where a missing one is an honest refusal.
class StringIO
  def getch
    getc
  end
end

class IO
  module ConsoleTermios__
    LINUX = RUBY_PLATFORM.include?("linux")
    # <termios.h>, the two platforms this answers for
    if LINUX
      IGNBRK = 0x1; BRKINT = 0x2; PARMRK = 0x8; ISTRIP = 0x20; INLCR = 0x40
      IGNCR = 0x80; ICRNL = 0x100; IXON = 0x400
      OPOST = 0x1
      CSIZE = 0x30; CS8 = 0x30; PARENB = 0x100
      ISIG = 0x1; ICANON = 0x2; ECHO = 0x8; ECHOE = 0x10; ECHOK = 0x20
      ECHONL = 0x40; IEXTEN = 0x8000
      VMIN = 6; VTIME = 5
    else
      IGNBRK = 0x1; BRKINT = 0x2; PARMRK = 0x8; ISTRIP = 0x20; INLCR = 0x40
      IGNCR = 0x80; ICRNL = 0x100; IXON = 0x200
      OPOST = 0x1
      CSIZE = 0x300; CS8 = 0x300; PARENB = 0x1000
      ISIG = 0x80; ICANON = 0x100; ECHO = 0x8; ECHOE = 0x2; ECHOK = 0x4
      ECHONL = 0x10; IEXTEN = 0x400
      VMIN = 16; VTIME = 17
    end

    # the name ruby's sys_fail gives the stream (rb_io_path)
    def self.name_of(io)
      pth = (io.path rescue nil)
      return pth if pth
      { 0 => "<STDIN>", 1 => "<STDOUT>", 2 => "<STDERR>" }[io.fileno] || ""
    end

    def self.fail(io, r)
      raise SystemCallError.new(name_of(io), -r)
    end

    # [iflag, oflag, cflag, lflag, ispeed, ospeed, cc bytes]
    def self.get(io)
      t = IO.__fdttyattrs(io.fileno)
      fail(io, t) if t.is_a?(Integer)
      f = t.split(" ")
      f[0, 6].map(&:to_i) + [[f[6].to_s].pack("H*").bytes]
    end

    def self.set(io, a, now = 0)
      text = a[0, 6].join(" ") + " " + a[6].pack("C*").unpack1("H*")
      r = IO.__fdttysetattrs(io.fileno, now, text)
      fail(io, r) if r.is_a?(Integer) && r < 0
    end

    # cfmakeraw, less ECHOE and ECHOK, with min / time / intr as asked
    # (console.c's set_rawmode)
    def self.raw!(a, min = nil, time = nil, intr = nil)
      a[0] &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON)
      a[1] &= ~OPOST
      a[3] &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN | ECHOE | ECHOK)
      a[2] = (a[2] & ~(CSIZE | PARENB)) | CS8
      a[6][VMIN] = 1
      a[6][VTIME] = 0
      a[6][VMIN] = min unless min.nil?
      a[6][VTIME] = time unless time.nil?
      if intr
        a[0] |= BRKINT
        a[3] |= ISIG
        a[1] |= OPOST
      end
      a
    end

    def self.cooked!(a)
      a[0] |= BRKINT | ISTRIP | ICRNL | IXON
      a[1] |= OPOST
      a[3] |= ECHO | ECHOE | ECHOK | ECHONL | ICANON | ISIG | IEXTEN
      a
    end

    def self.echo!(a, on)
      on ? a[3] |= (ECHO | ECHOE | ECHOK | ECHONL) : a[3] &= ~(ECHO | ECHOE | ECHOK | ECHONL)
      a
    end

    # min: an Integer; time: seconds, kept as tenths (console.c's rawmode_opt)
    def self.raw_opts(min, time, intr)
      unless min.nil?
        raise TypeError, "no implicit conversion of #{min.class} into Integer" unless min.is_a?(Integer)
      end
      unless time.nil?
        raise TypeError, "can't convert #{time.class} into time interval" unless time.is_a?(Numeric)
        time = (time * 10).to_i
      end
      [min, time, intr]
    end
  end

  def raw(min: nil, time: nil, intr: nil)
    min, time, intr = IO::ConsoleTermios__.raw_opts(min, time, intr)
    old = IO::ConsoleTermios__.get(self)
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.raw!(IO::ConsoleTermios__.get(self), min, time, intr))
    # with intr, the terminal turns its interrupt key into SIGINT, which is
    # ruby's Interrupt by default. A signal from outside is not caught here
    # unless trapped, so for the block ruby's default handler is the trap
    # (a handler the program set is left alone)
    ours = false
    if intr
      prev = Signal.trap("INT") { raise Interrupt, "" }
      if prev.nil? || prev == "DEFAULT" || prev == "SYSTEM_DEFAULT"
        ours = true
      else
        Signal.trap("INT", prev)
      end
    end
    begin
      yield self
    ensure
      IO::ConsoleTermios__.set(self, old)
      Signal.trap("INT", prev || "DEFAULT") if ours
    end
  end

  def raw!(min: nil, time: nil, intr: nil)
    min, time, intr = IO::ConsoleTermios__.raw_opts(min, time, intr)
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.raw!(IO::ConsoleTermios__.get(self), min, time, intr))
    self
  end

  def cooked
    old = IO::ConsoleTermios__.get(self)
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.cooked!(IO::ConsoleTermios__.get(self)))
    begin
      yield self
    ensure
      IO::ConsoleTermios__.set(self, old)
    end
  end

  def cooked!
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.cooked!(IO::ConsoleTermios__.get(self)))
    self
  end

  # The terminal's settings as an object (console.c's conmode): read off the
  # descriptor -- a stream that is no terminal is its errno, ENOTTY --
  # changed on the object, and written back with #console_mode=.
  class ConsoleMode
    VERSION = "0.8.1"
    class << self
      undef_method :new
    end
    def self.__of(a)
      m = allocate
      m.instance_variable_set(:@__a, a)
      m
    end
    def initialize_copy(o)
      a = o.instance_variable_get(:@__a)
      @__a = a[0, 6] + [a[6].dup]
      self
    end
    def echo=(on)
      ConsoleTermios__.echo!(@__a, on)
      self
    end
    def raw!(min: nil, time: nil, intr: nil)
      ConsoleTermios__.raw!(@__a, *ConsoleTermios__.raw_opts(min, time, intr))
      self
    end
    def raw(min: nil, time: nil, intr: nil) = dup.raw!(min: min, time: time, intr: intr)
  end

  def console_mode = ConsoleMode.__of(ConsoleTermios__.get(self))

  def console_mode=(mode)
    raise TypeError, "wrong argument type #{mode.class} (expected io/console/conmode)" unless ConsoleMode === mode
    ConsoleTermios__.set(self, mode.instance_variable_get(:@__a))
    mode
  end

  def echo=(on)
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.echo!(IO::ConsoleTermios__.get(self), on))
    on
  end

  def echo?
    (IO::ConsoleTermios__.get(self)[3] & (IO::ConsoleTermios__::ECHO | IO::ConsoleTermios__::ECHONL)) != 0
  end

  def noecho
    old = IO::ConsoleTermios__.get(self)
    IO::ConsoleTermios__.set(self, IO::ConsoleTermios__.echo!(IO::ConsoleTermios__.get(self), false))
    begin
      yield self
    ensure
      IO::ConsoleTermios__.set(self, old)
    end
  end

  # one character in raw mode. The wait is the scheduler's (IO.select), so
  # other threads run while it waits; a character already read into the
  # stream's buffer is answered first.
  def getch(min: nil, time: nil, intr: nil)
    raw(min: min, time: time, intr: intr) do
      t = time.nil? ? nil : time.to_f
      buffered = instance_variable_get(:@__io_rbuf)
      if buffered.is_a?(String) && !buffered.empty?
        getc
      elsif min == 0 && t.nil?
        IO.select([self], nil, nil, 0) ? getc : nil
      elsif t
        IO.select([self], nil, nil, t) ? getc : nil
      else
        getc
      end
    end
  end

  # the line read without echo, and a newline written after it (ruby's
  # console_getpass: rb_io_gets is "\n"-separated whatever $/ is)
  def getpass(prompt = nil)
    wio = equal?($stdin) ? $stderr : self
    if prompt
      wio.write(prompt)
      wio.flush
    end
    str = nil
    begin
      str = noecho { gets("\n") }
    ensure
      wio.write("\n")
      wio.flush
    end
    str&.chomp("\n")
  end

  def winsize
    w = IO.__fdwinsize(fileno)
    IO::ConsoleTermios__.fail(self, w) if w.is_a?(Integer)
    w[0, 2]
  end

  def winsize=(size)
    a = size.to_ary
    unless a.size == 2 || a.size == 4
      raise ArgumentError, "wrong number of arguments (given #{a.size}, expected 2 or 4)"
    end
    r, c, x, y = a.map { |v| v.to_int }
    rc = IO.__fdsetwinsize(fileno, r, c, x || 0, y || 0)
    IO::ConsoleTermios__.fail(self, rc) if rc < 0
    size
  end

  def iflush = __console_flush(0)
  def oflush = __console_flush(1)
  def ioflush = __console_flush(2)

  def __console_flush(which)
    r = IO.__fdttyflush(fileno, which)
    IO::ConsoleTermios__.fail(self, r) if r < 0
    self
  end
  private :__console_flush

  def beep
    write("\a")
    self
  end

  # the cursor as the terminal reports it ("\e[6n" answered by
  # "\e[row;colR"), 0-based
  def cursor
    raw do
      write("\e[6n")
      flush
      resp = +""
      until resp.end_with?("R")
        c = getc
        raise IOError, "no cursor position report" if c.nil?
        resp << c
      end
      m = /\e\[(\d+);(\d+)R\z/.match(resp)
      raise IOError, "bad cursor position report" unless m
      [m[1].to_i - 1, m[2].to_i - 1]
    end
  end

  def cursor=(pos)
    y, x = pos.to_ary
    goto(y, x)
  end

  def goto(y, x)
    write("\e[#{y.to_int + 1};#{x.to_int + 1}H")
    self
  end

  def __console_move(y, x)
    s = +""
    s << "\e[#{y.abs}#{y < 0 ? 'A' : 'B'}" if y != 0
    s << "\e[#{x.abs}#{x < 0 ? 'D' : 'C'}" if x != 0
    write(s) unless s.empty?
    self
  end
  private :__console_move

  def cursor_up(n) = __console_move(-n.to_int, 0)
  def cursor_down(n) = __console_move(n.to_int, 0)
  def cursor_left(n) = __console_move(0, -n.to_int)
  def cursor_right(n) = __console_move(0, n.to_int)

  def goto_column(x)
    write("\e[#{x.to_int + 1}G")
    self
  end

  def erase_line(mode)
    mode = mode.nil? ? 0 : mode.to_int
    raise ArgumentError, "argument out of range" unless (0..2).cover?(mode)
    write("\e[#{mode}K")
    self
  end

  def erase_screen(mode)
    mode = mode.nil? ? 0 : mode.to_int
    raise ArgumentError, "argument out of range" unless (0..3).cover?(mode)
    write("\e[#{mode}J")
    self
  end

  def scroll_forward(n)
    write("\e[#{n.to_int}S")
    self
  end

  def scroll_backward(n)
    write("\e[#{n.to_int}T")
    self
  end

  def clear_screen
    erase_screen(2)
    goto(0, 0)
  end

  # the process's terminal, /dev/tty, opened once and kept (nil without
  # one); a Symbol sends it that message, and :close closes it
  def self.console(*args, **kw)
    sym = args.empty? ? nil : args.shift
    con = @__console
    if sym == :close
      con.close if con && !con.closed?
      @__console = nil
      return nil
    end
    if con.nil? || con.closed?
      fd = (IO.sysopen("/dev/tty", "r+") rescue nil)
      return nil if fd.nil?
      # non-blocking, as IO.pipe's ends are: a read that would block waits in
      # the layer's readiness loop, where a signal (the interrupt key under
      # intr:) is delivered -- a blocking read(2) would hold it off
      IO.__fdnonblock(fd)
      con = File.new(fd, "r+")
      con.instance_variable_set(:@__io_path, "/dev/tty")
      con.sync = true
      @__console = con
    end
    return con if sym.nil?
    kw.empty? ? con.__send__(sym, *args) : con.__send__(sym, *args, **kw)
  end
end
