# frozen_string_literal: true
#
# StringIO, as mere-ruby answers `require "stringio"` (ruby's is a C
# extension, ext/stringio). Written here in Ruby over the String the stream
# wraps; every method was measured against the reference. Shipped through
# tools/gen_pathname_lib.rb.
class StringIO
  VERSION = "3.2.0"
  MAX_LENGTH = 9223372036854775807

  # ⚠ THE POSITION IS A BYTE OFFSET, as in ruby. It used to be a character
  #   index, so every multibyte string disagreed: #pos after reading "é",
  #   #getc from a position inside a character, #ungetbyte splitting one,
  #   #truncate and #write past the end. Every method below indexes bytes
  #   (byteslice, getbyte, bytesize) and hands out characters only where
  #   ruby does (#getc, #gets, #read with no length).

  # (StringIO.new(nil) is the null device: it has no string, reads nothing
  #  and drops what is written)
  def string
    @st.null ? nil : @st.string
  end
  # ⚠ `attr_accessor :string` gave a plain writer, so `io.string = obj`
  #   stored WHATEVER it was handed. ruby converts with #to_str and refuses
  #   what has none, and the assignment also RESETS the stream.
  def string=(str)
    raise FrozenError, "can't modify frozen StringIO: " + inspect if frozen?
    str = StringIO.__to_str(str) unless str.is_a?(String)
    @st.string = str
    @st.null = false
    @st.pos = 0
    @st.lineno = 0
    str
  end
  def pos = @st.pos
  def internal_encoding; nil; end

  # What #set_encoding named, or else the buffer's own encoding -- which
  # follows the string if its encoding is changed behind the stream's back.
  def external_encoding
    @enc || @st.string.encoding
  end

  # Sets the buffer's encoding too, unless the buffer is frozen; the stream
  # still reports the new one.
  def set_encoding(ext, _int = nil, _opt = nil)
    # ("BOM|UTF-8": the named encoding, unless a byte-order mark at the
    #  start names another -- which is then stepped over)
    if ext.is_a?(String) && ext.start_with?("BOM|")
      set_encoding(ext[4..])
      set_encoding_by_bom if @readable && !@st.null
      return self
    end
    enc = if ext.nil?
            Encoding.default_external
          elsif ext.is_a?(Encoding)
            ext
          else
            Encoding.find(ext.to_s.split(":")[0])
          end
    @enc = enc
    @st.string.force_encoding(enc) if @st.string && !@st.string.frozen?
    self
  end

  def self.open(string = nil, mode = nil, **opts)
    io = new(string, mode, **opts)
    return io unless block_given?
    begin
      yield io
    ensure
      # ⚠ ruby DROPS the string when the block ends -- `StringIO.open(s) { }`
      #   leaves #string nil, and the spec reads it on the raising path too.
      io.close
      io.__drop_string
    end
  end

  def __drop_string
    @st.string = nil
  end

  def self.__to_str(obj)
    unless obj.respond_to?(:to_str)
      raise TypeError, "no implicit conversion of " + obj.class.to_s + " into String"
    end
    r = obj.to_str
    unless r.is_a?(String)
      raise TypeError, "can't convert " + obj.class.to_s + " to String"
    end
    r
  end

  # (no string at all is a fresh one; a string given as nil is the null
  #  device -- the two spell the same default, so the default is a mark)
  NO_STRING = Object.new.freeze
  private_constant :NO_STRING
  # ruby's dup shares the struct behind the stream -- the string, the
  # position and the line number: a getc on either copy moves both. Only
  # the open/closed flags are the object's own.
  class State
    attr_accessor :string, :pos, :lineno, :null
  end
  private_constant :State
  def __st = @st
  def initialize_copy(other)
    super
    @st = other.__st
    self
  end
  def initialize(string = NO_STRING, mode = nil, **opts)
    @st = State.new
    # ⚠ THE STRING ITSELF, not a copy of it: ruby aliases it, which is the
    #   whole point of `StringIO.new(buf)`. And the conversion is #to_str,
    #   not #to_s -- a wrong argument must not become a plausible buffer.
    # no string at all is a new one in the default external encoding
    @st.null = string.nil?
    string = (+"").force_encoding(Encoding.default_external) if string.nil? || string.equal?(NO_STRING)
    @st.string = (string.is_a?(String) ? string : StringIO.__to_str(string))
    # mode: may come as a keyword instead (both at once is an error)
    if opts.key?(:mode)
      raise ArgumentError, "mode specified twice" if !mode.nil? && !opts[:mode].nil?
      mode = opts[:mode] if mode.nil?
    end
    @st.pos = 0
    @st.lineno = 0
    @closed = false
    @enc = nil
    mode = StringIO.__to_str(mode) unless mode.nil? || mode.is_a?(Integer) || mode.is_a?(String)
    # the keyword options may not say again what the mode already says
    raise ArgumentError, "both textmode and binmode specified" if opts[:binmode] && opts[:textmode]
    if mode.is_a?(String)
      flags, enc_name = mode.split(":", 2)
      if enc_name && (opts.key?(:encoding) || opts.key?(:external_encoding) || opts.key?(:internal_encoding))
        raise ArgumentError, "encoding specified twice"
      end
      raise ArgumentError, "binmode specified twice" if flags.include?("b") && opts.key?(:binmode)
      raise ArgumentError, "textmode specified twice" if flags.include?("t") && opts.key?(:textmode)
      if (flags.include?("b") && opts.key?(:textmode)) || (flags.include?("t") && opts.key?(:binmode))
        raise ArgumentError, "both textmode and binmode specified"
      end
      mode = flags
    end
    if mode.is_a?(Integer)
      # IO::RDONLY / WRONLY / RDWR, with APPEND and TRUNC
      acc = mode & 3
      @readable = acc != IO::WRONLY
      @writable = acc != IO::RDONLY
      @append = (mode & IO::APPEND) != 0
      trunc = (mode & IO::TRUNC) != 0
    else
      # a frozen string is read-only when no mode says otherwise
      m = mode.nil? ? (@st.string.frozen? ? "r" : "r+") : mode.to_s
      # (r / w / a, a +, b or t: `x`, `rx` and `rbt` are "invalid access mode")
      unless m.match?(/\A[rwa]\+?[bt]?\z/) || m.match?(/\A[rwa][bt]\+\z/)
        raise ArgumentError, "invalid access mode " + m
      end
      @readable = m.start_with?("r") || m.include?("+")
      @writable = !m.start_with?("r") || m.include?("+")
      # ⚠ "a" leaves the position at 0 and sends every WRITE to the end,
      #   even after a seek.
      @append = m.start_with?("a")
      trunc = m.start_with?("w")
    end
    # a frozen buffer cannot be opened for writing: EACCES, as a read-only
    # file would be
    raise Errno::EACCES if @writable && @st.string.frozen?
    # what the stream was OPENED as, which close_read/close_write ask about --
    # the flags above are the CURRENT state and a close clears them.
    @readable_mode = @readable
    @writable_mode = @writable
    # ⚠ `StringIO.new { }` does not run the block; it warns and says to use
    # ::open.
    warn("warning: StringIO::new() does not take block; use StringIO::open() instead") if block_given?
    # "w" TRUNCATES the string it was given rather than swapping in a fresh
    # one: the caller still holds the object and expects to see it emptied.
    @st.string.replace((+"").force_encoding(@st.string.encoding)) if trunc
    binmode if opts[:binmode]
    set_encoding(enc_name.split(":")[0]) if enc_name && !enc_name.empty?
  end

  def close
    @closed = true
    @readable = false
    @writable = false
    nil
  end

  def closed?
    @closed || (!@readable && !@writable)
  end

  def eof?
    @st.pos >= @st.string.bytesize
  end

  def size
    @st.string.bytesize
  end

  alias length size

  def rewind
    @st.pos = 0
    @st.lineno = 0
    0
  end

  def seek(amount, whence = 0)
    # the offset is a CONVERSION, as everywhere ruby takes one.
    unless amount.is_a?(Integer)
      unless amount.respond_to?(:to_int)
        raise TypeError, "no implicit conversion of " + amount.class.to_s + " into Integer"
      end
      amount = amount.to_int
    end
    raise IOError, "closed stream" if closed?
    whence = { SET: 0, CUR: 1, END: 2 }[whence] || whence if whence.is_a?(Symbol)
    raise Errno::EINVAL unless whence == 0 || whence == 1 || whence == 2
    np = if whence == 2
           @st.string.bytesize + amount
         elsif whence == 1
           @st.pos + amount
         else
           amount
         end
    # ⚠ no message: this interpreter prefixes the system text itself.
    raise Errno::EINVAL if np < 0
    @st.pos = np
    0
  end

  alias tell pos

  # A buffer argument is filled in place (through #to_str) and keeps its
  # own encoding; a frozen one is refused.
  def __sio_buf(buf)
    return nil if buf.nil?
    buf = StringIO.__to_str(buf) unless buf.is_a?(String)
    raise FrozenError, "can't modify frozen String: " + buf.inspect if buf.frozen?
    buf
  end

  def __sio_len(len)
    return nil if len.nil?
    unless len.is_a?(Integer)
      unless len.respond_to?(:to_int)
        raise TypeError, "no implicit conversion of " + len.class.to_s + " into Integer"
      end
      len = len.to_int
    end
    raise ArgumentError, "negative length " + len.to_s + " given" if len < 0
    len
  end

  # #read with a length answers BYTES (a binary string, nil at the end);
  # without one, the rest of the buffer in its own encoding ("" at the end).
  def read(len = nil, buf = nil)
    __sio_check_read
    len = __sio_len(len)
    buf = __sio_buf(buf)
    total = @st.string.bytesize
    # (the null device reads nothing but a zero length)
    return nil if @st.null && len != 0
    if len.nil?
      part = @st.pos >= total ? (+"").force_encoding(external_encoding) : @st.string.byteslice(@st.pos, total - @st.pos).force_encoding(external_encoding)
      @st.pos = total if @st.pos < total
    else
      if len == 0
        part = "".b
      elsif @st.pos >= total
        buf.replace((+"").force_encoding(buf.encoding)) if buf
        return nil
      else
        part = @st.string.byteslice(@st.pos, len).b
        @st.pos += part.bytesize
      end
    end
    return part unless buf
    enc = len.nil? ? part.encoding : buf.encoding
    buf.replace(part)
    buf.force_encoding(enc)
    buf
  end

  # #pread: `len` bytes from `offset`, the position left alone; EOFError
  # past the end, EINVAL for a negative offset
  def pread(len, offset, buf = nil)
    __sio_check_read
    len = __sio_len(len)
    raise ArgumentError, "negative string size (or size too big)" if len.nil?
    unless offset.is_a?(Integer)
      raise TypeError, "no implicit conversion of " + offset.class.to_s + " into Integer" unless offset.respond_to?(:to_int)
      offset = offset.to_int
    end
    return (buf.nil? ? "".b : buf) if len == 0
    raise Errno::EINVAL, "pread: Invalid offset argument: " + offset.to_s if offset < 0
    buf = __sio_buf(buf)
    if @st.null || offset >= @st.string.bytesize
      raise EOFError, "end of file reached"
    else
      part = @st.string.byteslice(offset, len).b
    end
    return part unless buf
    buf.replace(part)
    buf.force_encoding(Encoding::BINARY)
    buf
  end

  # The character boundary at or after byte `i`: a limit never splits one.
  def __sio_char_end(i)
    total = @st.string.bytesize
    return total if i >= total
    if @st.string.encoding == Encoding::UTF_8
      i += 1 while i < total && (@st.string.getbyte(i) & 0xC0) == 0x80
      return i
    end
    return i if @st.string.encoding.ascii_compatible? && @st.string.ascii_only?
    # (UTF-16/32 and the rest: the cut is moved until the piece is whole,
    #  at most a character's worth of bytes)
    j = i
    while j < total && j - i < 4 && !@st.string.byteslice(@st.pos, j - @st.pos).valid_encoding?
      j += 1
    end
    j
  end

  # ⚠ gets takes a LIMIT as well as a separator -- gets(3), gets(sep, 3) --
  # and a chomp: keyword. The limit counts bytes, rounded up to the end of
  # the character it lands in.
  def gets(sep = $/, limit = nil, chomp: false)
    $_ = __sio_getline(sep, limit, chomp)
  end

  # A separator is a String (through #to_str) or, in its place, a limit
  # (through #to_int); #readlines and #each_line read lines here too, and
  # only #gets sets $_.
  def __sio_getline(sep, limit, chomp)
    __sio_check_read
    unless sep.nil? || sep.is_a?(String)
      # (`gets(1, 1)`: the first argument is the separator once a limit follows)
      if !limit.nil? && !sep.respond_to?(:to_str)
        raise TypeError, "no implicit conversion of " + sep.class.to_s + " into String"
      end
      if sep.is_a?(Integer)
        limit = sep
        sep = $/
      elsif sep.respond_to?(:to_str)
        sep = sep.to_str
      elsif sep.respond_to?(:to_int)
        limit = sep.to_int
        sep = $/
      else
        raise TypeError, "no implicit conversion of " + sep.class.to_s + " into String"
      end
    end
    unless limit.nil? || limit.is_a?(Integer)
      raise TypeError, "no implicit conversion of " + limit.class.to_s + " into Integer" unless limit.respond_to?(:to_int)
      limit = limit.to_int
    end
    limit = nil if limit && limit < 0
    return nil if eof?
    return (+"").force_encoding(external_encoding) if limit == 0
    total = @st.string.bytesize
    para_sep = false
    if sep.nil?
      stop = total
    else
      paragraph = sep == ""
      if paragraph
        # (a paragraph starts past the blank lines, LF or CRLF, and ends
        #  with the blank lines after it)
        @st.pos += __sio_nl_at(@st.pos) while @st.pos < total && __sio_nl_at(@st.pos) > 0
        return nil if @st.pos >= total
        r = __sio_para_end(@st.pos)
        stop = r ? r : total
        para_sep = !r.nil?
      else
        # (the separator in the buffer's encoding: a UTF-16 buffer's "\n"
        #  is two bytes -- test_gets_utf_16)
        if !@st.string.encoding.ascii_compatible? && sep.encoding != @st.string.encoding
          sep = begin
                  sep.encode(@st.string.encoding)
                rescue EncodingError
                  sep
                end
        end
        idx = @st.string.b.byteindex(sep.b, @st.pos)
        stop = idx.nil? ? total : idx + sep.bytesize
      end
    end
    stop = __sio_char_end(@st.pos + limit) if limit && @st.pos + limit < stop
    line = @st.string.byteslice(@st.pos, stop - @st.pos).force_encoding(external_encoding)
    @st.pos = stop
    @st.lineno += 1
    if chomp && sep
      line = paragraph ? (para_sep ? line.sub(/(\r?\n)+\z/, "") : line) : __sio_chomp(line, sep)
    end
    $. = @st.lineno
    line
  end

  # the length of the newline at byte i: 1 for LF, 2 for CRLF, 0 for none
  def __sio_nl_at(i)
    b = @st.string.getbyte(i)
    return 1 if b == 10
    return 2 if b == 13 && @st.string.getbyte(i + 1) == 10
    0
  end

  # where the paragraph starting at `from` ends: past the newline that ends
  # its last line and every blank line after it; nil when no blank line
  # follows (the rest of the buffer is the paragraph)
  def __sio_para_end(from)
    total = @st.string.bytesize
    i = from
    while i < total
      n = __sio_nl_at(i)
      if n > 0
        j = i + n
        if j < total && __sio_nl_at(j) > 0
          j += __sio_nl_at(j) while j < total && __sio_nl_at(j) > 0
          return j
        end
        i = j
      else
        i += 1
      end
    end
    nil
  end

  def __sio_chomp(line, sep)
    return line.chomp if sep == "\n"
    return line.sub(/\n+\z/, "") if sep == "\n\n"
    line.end_with?(sep) ? line[0, line.length - sep.length] : line
  end

  def readlines(sep = $/, limit = nil, chomp: false)
    raise ArgumentError, "invalid limit: 0 for readlines" if limit == 0 || (sep.is_a?(Integer) && sep == 0)
    out = []
    while (line = __sio_getline(sep, limit, chomp))
      out.push(line)
    end
    out
  end

  def each_line(sep = $/, limit = nil, chomp: false)
    return to_enum(:each_line, sep, limit, chomp: chomp) unless block_given?
    raise ArgumentError, "invalid limit: 0 for each_line" if limit == 0 || (sep.is_a?(Integer) && sep == 0)
    while (line = __sio_getline(sep, limit, chomp))
      yield line
    end
    self
  end

  alias each each_line

  # One CHARACTER from the byte position -- or one byte, when the position
  # is inside a character or the bytes there are not one.
  def getc
    __sio_check_read
    return nil if eof?
    ch = @st.string.byteslice(@st.pos, 4).force_encoding(external_encoding)[0]
    @st.pos += ch.bytesize
    ch
  end

  # Pushes back before the position: over the bytes just read when there
  # are enough of them, otherwise in front of what is left (a position past
  # the end is padded with NULs first).
  def __sio_unget(s)
    return nil if @st.null
    raise IOError, "not modifiable string" if @st.string.frozen?
    if @st.pos > @st.string.bytesize
      @st.string.replace((@st.string.b + ("\0" * (@st.pos - @st.string.bytesize))).force_encoding(@st.string.encoding))
    end
    n = s.bytesize
    enc = @st.string.encoding
    if n <= @st.pos
      head = @st.string.byteslice(0, @st.pos - n).b
      tail = @st.string.byteslice(@st.pos, @st.string.bytesize - @st.pos).b
      @st.string.replace((head + s.b + tail).force_encoding(enc))
      @st.pos -= n
    else
      tail = @st.string.byteslice(@st.pos, @st.string.bytesize - @st.pos).b
      @st.string.replace((s.b + tail).force_encoding(enc))
      @st.pos = 0
    end
    nil
  end

  def ungetc(c)
    __sio_check_read
    return nil if c.nil?
    c = c.is_a?(Integer) ? c.chr(external_encoding) : StringIO.__to_str(c)
    __sio_unget(c)
  end

  # at position 0 this PREPENDS; anywhere else it overwrites the bytes ending
  # at the position and moves back over them.
  def ungetbyte(b)
    return nil if b.nil?
    __sio_check_read
    s = b.is_a?(Integer) ? (b & 255).chr : b.to_s
    __sio_unget(s)
  end

  def write(*args)
    __sio_check_write
    n = 0
    args.each do |a|
      s = a.to_s
      enc = @st.string.encoding
      # ⚠ into the stream's encoding, as strio_write converts: a UTF-8
      # "hello" written to a UTF-16BE stream was stored as its UTF-8 bytes.
      # BINARY and US-ASCII on either side mean the bytes are taken as they are.
      xe = external_encoding
      if xe != Encoding::BINARY && xe != Encoding::US_ASCII &&
         s.encoding != xe && s.encoding != Encoding::BINARY && s.encoding != Encoding::US_ASCII
        s = begin
              s.encode(xe)
            rescue EncodingError
              # (what cannot be converted is appended as it is when it is
              #  ASCII, and refused otherwise, as rb_enc_check refuses)
              if s.ascii_only?
                s
              else
                raise Encoding::CompatibilityError, "incompatible character encodings: " + xe.to_s + " and " + s.encoding.to_s
              end
            end
      end
      # (a write at the very end of what a position can be: ArgumentError,
      #  not an allocation of that many NULs)
      raise ArgumentError, "pos + len overflows" if @st.pos > MAX_LENGTH - s.bytesize
      next if @st.null
      # (an ASCII-only buffer labelled US-ASCII takes the encoding of the
      #  first non-ASCII string written, as rb_enc_cr_str_buf_cat does)
      if enc == Encoding::US_ASCII && !s.ascii_only? && s.encoding != Encoding::BINARY && !@st.string.frozen?
        @st.string.force_encoding(s.encoding)
        enc = s.encoding
      end
      @st.pos = @st.string.bytesize if @append
      size = @st.string.bytesize
      # ⚠ AT THE END OF THE STREAM A WRITE IS AN APPEND, and is made as
      #   one: the splice below rebuilds the whole string, so writing a
      #   log line by line was quadratic (20,000 writes of 2 bytes, the
      #   common case, took seconds). append_as_bytes is the same bytes
      #   with the encoding left alone, which is what the splice makes.
      if @st.pos == size
        @st.string.append_as_bytes(s)
      else
        head = @st.string.byteslice(0, @st.pos < size ? @st.pos : size).b
        head << ("\0" * (@st.pos - size)) if @st.pos > size
        rest_at = @st.pos + s.bytesize
        tail = rest_at < size ? @st.string.byteslice(rest_at, size - rest_at).b : "".b
        @st.string.replace((head + s.b + tail).force_encoding(enc))
      end
      @st.pos += s.bytesize
      n += s.bytesize
    end
    n
  end

  def <<(obj)
    write(obj)
    self
  end

  # With no arguments #print writes $_; $, goes between the arguments and
  # $\ after them, as IO#print does.
  def print(*args)
    args = [$_] if args.empty?
    args.each_with_index do |a, i|
      write($,) if $, && i > 0
      write(a)
    end
    write($\) if $\
    nil
  end

  # An array that contains itself is written as [...], as IO#puts does;
  # following it went down forever.
  def puts(*args)
    __sio_puts(args, {})
  end

  def __sio_puts(args, seen)
    if args.empty?
      write("\n")
      return nil
    end
    args.each do |a|
      orig = a
      unless a.is_a?(Array) || a.is_a?(String) || !a.respond_to?(:to_ary)
        ary = a.to_ary
        a = ary if ary.is_a?(Array)
      end
      if a.is_a?(Array)
        if seen[orig.__id__]
          write("[...]\n")
          next
        end
        seen[orig.__id__] = true
        __sio_puts(a, seen)
        seen.delete(orig.__id__)
      else
        s = a.to_s
        # a #to_s that is not a String is replaced by the default one
        s = format("#<%s:0x%016x>", a.class.to_s, a.__id__) unless s.is_a?(String)
        write(s)
        write("\n") unless s.end_with?("\n")
      end
    end
    nil
  end

  def printf(fmt, *args)
    write(format(fmt, *args))
    nil
  end

  # Bytes, and growing pads with NULs.
  def truncate(len)
    __sio_check_write
    unless len.is_a?(Integer)
      raise TypeError, "no implicit conversion of " + len.class.to_s + " into Integer" unless len.respond_to?(:to_int)
      len = len.to_int
    end
    raise Errno::EINVAL, "negative length" if len < 0
    size = @st.string.bytesize
    enc = @st.string.encoding
    if len < size
      @st.string.replace(@st.string.byteslice(0, len).force_encoding(enc))
    else
      @st.string.replace((@st.string.b + ("\0" * (len - size))).force_encoding(enc))
    end
    0
  end

  def flush
    self
  end

  def sync
    true
  end

  def sync=(v)
    v
  end

  def tty?
    false
  end

  alias isatty tty?

  def fileno
    nil
  end

  # Everything below was measured against the reference ruby rather than
  # guessed from the name. Two surprises: #putc returns its ARGUMENT (not the
  # byte written), and #lineno counts calls to #gets -- so readline, readlines
  # and each_line advance it, and #getc does not.

  def __sio_check_read
    raise IOError, "not opened for reading" unless @readable
  end

  def __sio_check_write
    raise FrozenError, "can't modify frozen StringIO: " + inspect if frozen?
    raise IOError, "not opened for writing" unless @writable
    # (a buffer frozen after the stream opened: ruby says the same)
    raise IOError, "not opened for writing" if !@st.null && @st.string.frozen?
  end
  private :__sio_check_read
  private :__sio_check_write

  def fsync
    0
  end

  def pid
    nil
  end

  def fcntl(*a)
    raise NotImplementedError, "fcntl() function is unimplemented on this machine"
  end

  def closed_read?
    !@readable
  end

  def closed_write?
    !@writable
  end

  def lineno
    @st.lineno
  end

  def lineno=(n)
    @st.lineno = n
  end

  def getbyte
    __sio_check_read
    return nil if @st.pos >= @st.string.bytesize
    b = @st.string.getbyte(@st.pos)
    @st.pos += 1
    b
  end

  def readbyte
    b = getbyte
    raise EOFError, "end of file reached" if b.nil?
    b
  end

  def readchar
    c = getc
    raise EOFError, "end of file reached" if c.nil?
    c
  end

  def readline(sep = $/, limit = nil, chomp: false)
    l = gets(sep, limit, chomp: chomp)
    raise EOFError, "end of file reached" if l.nil?
    l
  end

  def each_byte
    __sio_check_read
    return to_enum(:each_byte) unless block_given?
    while (b = getbyte)
      yield b
    end
    self
  end

  def each_char
    __sio_check_read
    return to_enum(:each_char) unless block_given?
    while (c = getc)
      yield c
    end
    self
  end

  # from the position; a broken sequence is ArgumentError, as String#ord says
  def each_codepoint
    return to_enum(:each_codepoint) unless block_given?
    __sio_check_read
    while (c = getc)
      yield c.ord
    end
    self
  end

  def putc(obj)
    __sio_check_write
    s = if obj.is_a?(String)
          obj[0, 1]
        elsif obj.is_a?(Integer)
          (obj & 255).chr
        elsif obj.respond_to?(:to_int)
          (obj.to_int & 255).chr
        else
          raise TypeError, "no implicit conversion of " + obj.class.to_s + " into Integer"
        end
    write(s)
    obj
  end

  def sysread(len = nil, buf = nil)
    __sio_check_read
    len = __sio_len(len)
    if len == 0
      buf = __sio_buf(buf)
      buf&.replace("")
      return buf || ""
    end
    # at the end, a LENGTH asked for is EOFError; no length reads ""
    if eof? && !len.nil?
      buf = __sio_buf(buf)
      buf&.replace("")
      raise EOFError, "end of file reached"
    end
    read(len, buf)
  end

  alias readpartial sysread

  # one String (converted with #to_s), and the byte count, as #write
  def syswrite(s) = write(s)

  # exception: false answers nil at the end instead of raising EOFError
  def read_nonblock(len, buf = nil, exception: true)
    return nil if !exception && len != 0 && eof?
    sysread(len, buf)
  end

  def write_nonblock(s, exception: true)
    write(s)
  end

  def reopen(other = nil, mode = nil)
    other = other.to_strio if mode.nil? && !other.nil? && !other.is_a?(String) && !other.is_a?(StringIO) && other.respond_to?(:to_strio)
    if other.is_a?(StringIO)
      # (shared, as dup shares it: the position moves in both)
      @st = other.__st
      @readable = other.__sio_readable
      @writable = other.__sio_writable
      @readable_mode = @readable
      @writable_mode = @writable
      @append = false
      @closed = false
      return self
    end
    initialize(other.nil? ? +"" : other, mode)
    self
  end

  def __sio_readable = @readable
  def __sio_writable = @writable

  # A byte-order mark picks the encoding and is stepped over. UTF-32LE's
  # mark begins with UTF-16LE's, so it is asked first.
  def set_encoding_by_bom
    raise FrozenError, "can't modify frozen StringIO: " + inspect if frozen?
    return nil unless @readable
    b = @st.string.byteslice(0, 4).bytes
    enc, len =
      if b[0, 3] == [0xEF, 0xBB, 0xBF] then [Encoding::UTF_8, 3]
      elsif b == [0xFF, 0xFE, 0, 0] then [Encoding::UTF_32LE, 4]
      elsif b == [0, 0, 0xFE, 0xFF] then [Encoding::UTF_32BE, 4]
      elsif b[0, 2] == [0xFF, 0xFE] then [Encoding::UTF_16LE, 2]
      elsif b[0, 2] == [0xFE, 0xFF] then [Encoding::UTF_16BE, 2]
      else [nil, 0]
      end
    return nil unless enc
    set_encoding(enc)
    @st.pos = len
    enc
  end

  # ruby's StringIO has no instance variables to show: its inspect is to_s
  def inspect
    to_s
  end
end
class StringIO
  # ruby's StringIO includes Enumerable, and `StringIO.include?(Enumerable)` is
  # a spec of its own.
  include Enumerable

  # `binmode` puts the buffer into ASCII-8BIT, which is what
  # `external_encoding` reports afterwards.
  def binmode
    @enc = Encoding::BINARY
    @st.string.force_encoding(Encoding::BINARY) unless @st.string.frozen?
    self
  end

  # A negative position is EINVAL. StringIO is not a String: there is no
  # counting from the end here.
  def pos=(n)
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    raise Errno::EINVAL if n < 0
    @st.pos = n
  end

  # ⚠ `eof` must BE `eof?`, not call it: the spec compares the two
  # UnboundMethods.
  alias_method :eof, :eof?

  # Closing a side is about the MODE it was opened with, and closing it twice
  # is not an error.
  def close_read
    raise IOError, "closing non-duplex IO for reading" unless __opened_readable?
    @readable = false
    nil
  end

  def close_write
    raise IOError, "closing non-duplex IO for writing" unless __opened_writable?
    @writable = false
    nil
  end

  def __opened_readable? = @readable_mode
  def __opened_writable? = @writable_mode
  private :__opened_readable?, :__opened_writable?
end
