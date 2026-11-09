# Gzip framing and bounded IO over the resumable RFC 1951 engine.
module Zlib
  class GzipFile
    class Error < Zlib::Error
      attr_reader :input
    end
    class CRCError < Error; end
    class LengthError < Error; end
    class NoFooter < Error; end

    def self.wrap(io, *args, **opts)
      gz = new(io, *args, **opts)
      return gz unless block_given?
      begin
        yield gz
      ensure
        gz.close unless gz.closed?
      end
    end

    def __ready
      raise Zlib::GzipFile::Error, 'closed gzip stream' if @closed
    end
    def closed?; @closed ? true : false; end
    def to_io; __ready; @io; end
    def path; @io.path; end
    def sync; __ready; @sync ? true : false; end
    def sync=(value); __ready; @sync = value; value; end
    def mtime; __ready; @mtime; end
    def orig_name; __ready; @orig_name && @orig_name.dup; end
    def comment; __ready; @comment && @comment.dup; end
    def level; __ready; @level; end
    def os_code; __ready; @os_code || OS_CODE; end
    def crc; __ready; @crc; end
    def close
      return nil if @closed
      io = finish
      io.close if io.respond_to?(:close)
      io
    end
  end

  class GzipWriter < GzipFile
    def self.open(path, *args, **opts, &block)
      io = File.open(path, 'wb')
      begin
        wrap(io, *args, **opts, &block)
      rescue Exception
        io.close unless io.closed?
        raise
      end
    end

    def initialize(io, level = DEFAULT_COMPRESSION, strategy = DEFAULT_STRATEGY, **opts)
      @io = io
      @level = level.nil? ? DEFAULT_COMPRESSION : Integer(level)
      @z = Deflate.new(@level, -MAX_WBITS, DEF_MEM_LEVEL, strategy)
      @closed = false
      @header_written = false
      @mtime = Time.now
      @crc = 0
      @pos = 0
      @compressed = +''.b
      @external = opts[:external_encoding] || opts[:encoding]
      @internal = opts[:internal_encoding]
    end

    def __header
      return if @header_written
      @header_written = true
      flags = (@orig_name ? 8 : 0) | (@comment ? 16 : 0)
      xflags = @level == 9 ? 2 : (@level == 1 ? 4 : 0)
      @compressed << [31, 139, 8, flags, @mtime.to_i & 0xffffffff, xflags, OS_CODE].pack('C4VC2')
      @compressed << @orig_name.b << "\0" if @orig_name
      @compressed << @comment.b << "\0" if @comment
    end

    def __write_output(force = false)
      if force || @compressed.bytesize >= 2048
        @io.write(@compressed) unless @compressed.empty?
        @compressed = +''.b
      end
    end

    def write(str)
      __ready
      s = Zlib.__string(str)
      s = s.encode(@external) if @external
      s = s.b
      __header
      @crc = Zlib.crc32(s, @crc)
      @pos += s.bytesize
      @compressed << @z.deflate(s, @sync ? SYNC_FLUSH : NO_FLUSH)
      __write_output(@sync)
      s.bytesize
    end
    def <<(str); write(str); self; end
    def print(*args)
      args = [$_] if args.empty?
      args.each { |a| write(a.to_s) }
      write($\) if $\
      nil
    end
    def puts(*args)
      args = [''] if args.empty?
      args.each do |a|
        if a.is_a?(Array)
          a.each { |v| puts(v) }
        else
          s = a.nil? ? '' : a.to_s
          write(s)
          write("\n") unless s.end_with?("\n")
        end
      end
      nil
    end
    def printf(fmt, *args); write(format(fmt, *args)); nil; end
    def putc(c); write(c.is_a?(Integer) ? (c & 255).chr.b : c.to_s.byteslice(0, 1)); c; end
    def pos; __ready; @pos; end
    alias tell pos

    def flush(mode = SYNC_FLUSH)
      __ready
      __header
      @compressed << @z.flush(mode)
      __write_output(true)
      @io.flush if @io.respond_to?(:flush)
      self
    end

    def finish
      __ready
      __header
      @compressed << @z.finish << [@crc, @pos & 0xffffffff].pack('V2')
      __write_output(true)
      @z.close
      @closed = true
      @io
    end

    def mtime=(value)
      __ready
      raise Zlib::GzipFile::Error, 'header is already written' if @header_written
      @mtime = value.is_a?(Time) ? value : Time.at(Integer(value))
      value
    end
    def orig_name=(value)
      __ready
      raise Zlib::GzipFile::Error, 'header is already written' if @header_written
      @orig_name = Zlib.__string(value).split("\0", 2).first || ''
      value
    end
    def comment=(value)
      __ready
      raise Zlib::GzipFile::Error, 'header is already written' if @header_written
      @comment = Zlib.__string(value).split("\0", 2).first || ''
      value
    end
  end

  class GzipReader < GzipFile
    include Enumerable
    def self.open(path, *args, **opts, &block)
      io = File.open(path, 'rb')
      begin
        wrap(io, *args, **opts, &block)
      rescue Exception
        io.close unless io.closed?
        raise
      end
    end

    def initialize(io, options = nil, **opts)
      @io = io
      @options = (options || {}).merge(opts)
      @closed = false
      @raw_len = 0
      __reset_reader
    end

    def __reset_reader
      @z = Inflate.new(31)
      @z.instance_variable_set(:@reader_mode, true)
      @data = +''.b
      @pushback = +''.b
      @pos = 0
      @lineno = 0
      @crc = 0
      @ended = false
      @source_end = false
      external = @options[:external_encoding] || @options[:encoding]
      internal = @options[:internal_encoding]
      if external && external.to_s.include?(':')
        external, internal = external.to_s.split(':', 2)
      end
      @enc = external ? Encoding.find(external.to_s) : Encoding.default_external
      @internal = internal && internal != '-' ? Encoding.find(internal.to_s) : nil
      loop do
        begin
          break if @z.__header
        rescue Zlib::DataError
          __gzip_error(Zlib::GzipFile::Error, 'not in gzip format', @z.instance_variable_get(:@in))
        end
        unless __read_input
          input = @z.instance_variable_get(:@in)
          __gzip_error(Zlib::GzipFile::Error, 'not in gzip format', input.empty? ? nil : input)
        end
      end
      @mtime = Time.at(@z.instance_variable_get(:@gzip_mtime))
      @orig_name = @z.instance_variable_get(:@gzip_name)
      @comment = @z.instance_variable_get(:@gzip_comment)
      @os_code = @z.instance_variable_get(:@gzip_os)
      @level = @z.instance_variable_get(:@gzip_level)
    end

    def __gzip_error(klass, message, input = nil)
      error = klass.new(message)
      error.instance_variable_set(:@input, input)
      raise error
    end

    def __read_input
      return false if @source_end
      begin
        s = @io.readpartial(2048)
        s = Zlib.__string(s)
      rescue NoMethodError
        s = @io.read(2048)
      rescue EOFError
        s = nil
      end
      if s.nil? || s.empty?
        @source_end = true
        false
      else
        s = Zlib.__string(s).b
        @raw_len += s.bytesize
        @z.instance_variable_get(:@in) << s
        true
      end
    end

    def __fill
      return false if @ended
      loop do
        begin
          @z.__decode(16384)
        rescue Zlib::DataError => e
          klass = e.message == 'incorrect length check' ? LengthError : (e.message == 'incorrect data check' ? CRCError : Zlib::GzipFile::Error)
          __gzip_error(klass, e.message == 'incorrect data check' ? 'invalid compressed data -- crc error' : e.message)
        end
        # GzipReader retains the input after the member; it is not decoded data.
        @data << @z.flush_next_out
        if @z.finished?
          @ended = true
          @unused = @z.instance_variable_get(:@in)
        end
        return true unless @data.empty?
        return false if @ended
        unless __read_input
          kind = @z.instance_variable_get(:@phase) == :trailer && @z.instance_variable_get(:@in).empty? ? NoFooter : Zlib::GzipFile::Error
          __gzip_error(kind, kind == NoFooter ? 'footer is not found' : 'unexpected end of file')
        end
      end
    end

    def read(length = nil, buffer = nil)
      __ready
      unless length.nil?
        length = Integer(length)
        raise ArgumentError, "negative length #{length} given" if length < 0
      end
      result = +''.b
      while length.nil? || result.bytesize < length
        if @pushback.empty? && @data.empty?
          break unless __fill
        end
        source = @pushback.empty? ? @data : @pushback
        n = length.nil? ? source.bytesize : [source.bytesize, length - result.bytesize].min
        piece = source.byteslice(0, n)
        @crc = Zlib.crc32(piece, @crc) if @pushback.empty?
        result << piece
        source.replace(source.byteslice(n, source.bytesize - n))
      end
      @pos += result.bytesize
      if length && length > 0 && result.empty?
        buffer.clear if buffer
        return nil
      end
      if length.nil?
        result.force_encoding(@enc)
        result = result.encode(@internal) if @internal
      end
      buffer ? buffer.replace(result) : result
    end

    def readpartial(length, buffer = nil)
      __ready
      length = Integer(length)
      raise ArgumentError, "negative length #{length} given" if length < 0
      return buffer ? buffer.replace(+''.b) : +''.b if length == 0
      if @pushback.empty? && @data.empty?
        unless __fill
          buffer.clear if buffer
          raise EOFError, 'end of file reached'
        end
      end
      read([length, @pushback.bytesize + @data.bytesize].min, buffer)
    end

    def eof?
      __ready
      @pushback.empty? && @data.empty? && !__fill
    end
    alias eof eof?
    def pos; __ready; @pos; end
    alias tell pos
    def lineno; __ready; @lineno; end
    def lineno=(n); __ready; @lineno = Integer(n); end
    def external_encoding = @enc
    def unused
      __ready
      eof? ? (@unused && !@unused.empty? ? @unused.dup : nil) : nil
    end
    def getbyte; s = read(1); s && s.getbyte(0); end
    def readbyte; getbyte || (raise EOFError, 'end of file reached'); end
    def getc
      return nil if eof?
      s = read(1).force_encoding(@enc)
      s << read(1).force_encoding(@enc) until s.valid_encoding? || eof?
      @internal ? s.encode(@internal) : s
    end
    def readchar; getc || (raise EOFError, 'end of file reached'); end
    def ungetbyte(value)
      __ready
      return nil if value.nil?
      s = value.is_a?(Integer) ? (value & 255).chr.b : Zlib.__string(value).b
      @pushback = s + @pushback
      @pos -= s.bytesize
      nil
    end
    def ungetc(value)
      return nil if value.nil?
      ungetbyte(value.is_a?(Integer) ? value.chr(@enc) : Zlib.__string(value))
    end

    def gets(separator = $/, limit = nil, chomp: false)
      __ready
      if separator.is_a?(Integer)
        limit = separator
        separator = $/
      end
      limit = Integer(limit) if limit
      return +''.force_encoding(@enc) if limit == 0
      return nil if eof?
      sep = separator.nil? ? nil : Zlib.__string(separator).b
      paragraph = sep == ''
      if paragraph
        while (b = getbyte) == 10; end
        ungetbyte(b) if b
        return nil unless b
        sep = "\n\n".b
      end
      result = +''.b
      until eof?
        result << read(1)
        break if (limit && limit > 0 && result.bytesize >= limit) || (sep && result.end_with?(sep))
      end
      until result.dup.force_encoding(@enc).valid_encoding? || eof?
        result << read(1)
      end
      if paragraph
        while (b = getbyte) == 10; end
        ungetbyte(b) if b
      end
      @lineno += 1
      result.force_encoding(@enc)
      result = result.encode(@internal) if @internal
      result = result.chomp(separator || $/) if chomp
      result
    end
    def readline(*args, **opts); gets(*args, **opts) || (raise EOFError, 'end of file reached'); end
    def each(*args, **opts)
      return to_enum(:each, *args, **opts) unless block_given?
      while (line = gets(*args, **opts)); yield line; end
      self
    end
    alias each_line each
    def readlines(*args, **opts); each(*args, **opts).to_a; end
    def each_byte
      return to_enum(:each_byte) unless block_given?
      while (b = getbyte); yield b; end
      self
    end
    def each_char
      return to_enum(:each_char) unless block_given?
      while (c = getc); yield c; end
      self
    end
    def rewind
      __ready
      @io.seek(-@raw_len, IO::SEEK_CUR)
      @raw_len = 0
      @z.close
      __reset_reader
      0
    end
    def finish
      __ready
      @z.close
      @closed = true
      @io
    end

    def self.zcat(io, **opts)
      out = +''.b
      loop do
        gz = new(io, **opts)
        data = gz.read
        block_given? ? yield(data) : out << data
        unused = gz.unused
        gz.finish
        break unless unused || (io.respond_to?(:eof?) && !io.eof?)
        io.seek(-unused.bytesize, IO::SEEK_CUR) if unused
      end
      block_given? ? nil : out
    end
  end

  def self.gzip(str, level: DEFAULT_COMPRESSION, strategy: DEFAULT_STRATEGY)
    z = Deflate.new(level, MAX_WBITS + 16, DEF_MEM_LEVEL, strategy)
    begin
      z.deflate(__string(str), FINISH)
    ensure
      z.close unless z.closed?
    end
  end

  def self.gunzip(str)
    # A minimal IO keeps this helper independent of StringIO's load order.
    io = GzipStringIO.new(__string(str).b)
    gz = GzipReader.new(io, external_encoding: Encoding::ASCII_8BIT)
    begin
      gz.read
    ensure
      gz.finish unless gz.closed?
    end
  end
  class GzipStringIO
    def initialize(data); @data = data; @pos = 0; end
    def read(n)
      return nil if @pos >= @data.bytesize
      s = @data.byteslice(@pos, n)
      @pos += s.bytesize
      s
    end
  end
  private_constant :GzipStringIO
end
