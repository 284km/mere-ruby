# RFC 1950/1951 streaming API over the pure Mere engine in m_zstream.mere.
module Zlib
  class StreamEnd < Error; end

  def self.__string(value)
    return value if value.is_a?(String)
    unless value.respond_to?(:to_str)
      raise TypeError, "no implicit conversion of #{value.nil? ? 'nil' : value.class} into String"
    end
    result = value.to_str
    raise TypeError, 'to_str did not return String' unless result.is_a?(String)
    result
  end

  class ZStream
    def __init_stream
      @in = +''.b
      @out = +''.b
      @history = +''.b
      @closed = false
      @finished = false
      @total_in = 0
      @total_out = 0
      @adler = 1
      @avail_out = 0
      @data_type = Zlib::UNKNOWN
      @lock = Thread::Mutex.new
    end

    def __ready
      raise Zlib::Error, 'stream is not ready' if @closed || @closed.nil?
    end

    def total_in; __ready; @total_in; end
    def total_out; __ready; @total_out; end
    def avail_in; __ready; @in.bytesize; end
    def avail_out; __ready; @avail_out; end
    def avail_out=(n); __ready; @avail_out = Integer(n); n; end
    def adler; __ready; @adler; end
    def data_type; __ready; @data_type; end
    def finished?; __ready; @finished; end
    alias stream_end? finished?
    def closed?; @closed ? true : false; end
    alias ended? closed?
    def close; __ready; @closed = true; @in.clear; @out.clear; @history.clear; nil; end
    alias end close
    def reset; __ready; __reset; nil; end
    def flush_next_in; __ready; s = @in; @in = +''.b; s; end
    def flush_next_out; __ready; s = @out; @out = +''.b; s; end

    def __drain(final)
      if block_given?
        while @out.bytesize >= 16384 || (final && !@out.empty?)
          n = [16384, @out.bytesize].min
          s = @out.byteslice(0, n)
          @out = @out.byteslice(n, @out.bytesize - n)
          yield s
        end
        nil
      else
        flush_next_out
      end
    end

    def initialize_copy(other)
      super
      @in = @in.dup
      @out = @out.dup
      @history = @history.dup
      @lock = Thread::Mutex.new
    end
  end

  class Deflate < ZStream
    def initialize(level = DEFAULT_COMPRESSION, window_bits = MAX_WBITS, mem_level = DEF_MEM_LEVEL, strategy = DEFAULT_STRATEGY)
      @level = level.nil? ? -1 : Integer(level)
      @wbits = window_bits.nil? ? 15 : Integer(window_bits)
      @mem_level = mem_level.nil? ? 8 : Integer(mem_level)
      @strategy = strategy.nil? ? 0 : Integer(strategy)
      unless (-1..9).include?(@level) && (1..9).include?(@mem_level) && (0..4).include?(@strategy) && ((8..15).include?(@wbits.abs) || (24..31).include?(@wbits))
        raise StreamError, 'stream error'
      end
      @window = @wbits.abs > 15 ? @wbits - 16 : @wbits.abs
      @window = 9 if @window == 8
      __reset
    end

    def __reset
      __init_stream
      @bb = 0
      @bc = 0
      @started = false
      @dictionary = nil
      @input_count = 0
      @checkpoint = 16384
      @in_offset = 0
      @crc = 0
    end

    def self.deflate(str, level = DEFAULT_COMPRESSION, &block)
      z = new(level)
      begin
        z.deflate(str, FINISH, &block)
      ensure
        z.close unless z.closed?
      end
    end

    def __header
      return if @started
      @started = true
      if @wbits > 15
        @out << [31, 139, 8, 0, 0, 0, 0, 0, @level == 9 ? 2 : (@level == 1 ? 4 : 0), OS_CODE].pack('C*')
      elsif @wbits > 0
        cmf = ((@window - 8) << 4) | 8
        flevel = @level == 0 || @level == 1 || @strategy >= 2 ? 0 : (@level == 9 ? 3 : (@level > 0 && @level < 6 ? 1 : 2))
        flg = (flevel << 6) | (@dictionary ? 32 : 0)
        flg += (31 - ((cmf << 8) + flg) % 31) % 31
        @out << [cmf, flg].pack('C*')
        @out << [@dict_adler].pack('N') if @dictionary
      end
      @total_out = @out.bytesize
      @adler = @wbits > 15 ? 0 : 1
    end

    def __block(flush)
      remaining = @in.bytesize - @in_offset
      size = [remaining, [32768, @checkpoint].max].min
      source = @in.byteslice(@in_offset, size)
      mode = size == remaining ? flush : NO_FLUSH
      bytes, history, bb, bc, used = Zlib.__deflate_step(source, @history, @bb, @bc, mode, @level < 0 ? 6 : @level, @strategy, @window)
      @history = history
      @bb = bb
      @bc = bc
      @out << bytes
      @total_out += bytes.bytesize
      if used > 0
        @data_type = Zlib.__data_type(source.byteslice(0, used)) if @data_type == Zlib::UNKNOWN
        @in_offset += used
      end
      used
    end

    def __pump(flush, &block)
      __header
      loop do
        old_size = @in.bytesize - @in_offset
        break if flush == NO_FLUSH && old_size < @checkpoint
        used = __block(flush)
        if used == 0 && old_size > 0
          @checkpoint = [@checkpoint * 2, 8 * 1024 * 1024].min
          break if flush == NO_FLUSH && old_size < @checkpoint
          next
        end
        @checkpoint = 16384
        if used == old_size && flush == FINISH
          tail = @wbits > 15 ? [@crc, @input_count & 0xffffffff].pack('V2') : (@wbits > 0 ? [@adler].pack('N') : +''.b)
          @out << tail
          @total_out += tail.bytesize
          @finished = true
        end
        __drain(@finished, &block) if block
        break if used == old_size
      end
    ensure
      # Compact once per API call, including a block break. Copying the whole
      # remaining suffix once per compressed block made large inputs quadratic.
      if @in_offset && @in_offset > 0
        @in = @in.byteslice(@in_offset, @in.bytesize - @in_offset)
        @in_offset = 0
      end
    end

    def deflate(str, flush = NO_FLUSH, &block)
      __ready
      @lock.synchronize do
        raise StreamError, 'stream error' if @finished
        flush = str.nil? ? FINISH : Integer(flush)
        raise StreamError, 'stream error' unless (0..5).include?(flush)
        s = str.nil? ? +''.b : Zlib.__string(str).b
        __header
        @adler = @wbits > 15 ? Zlib.crc32(s, @adler) : Zlib.adler32(s, @adler)
        @crc = Zlib.crc32(s, @crc)
        @in << s
        @total_in += s.bytesize
        @input_count += s.bytesize
        __pump(flush, &block)
        __drain(@finished, &block)
      end
    end

    def <<(str)
      __ready
      @lock.synchronize do
        raise StreamError, 'stream error' if @finished
        if str.nil?
          __pump(FINISH)
        else
          s = Zlib.__string(str).b
          __header
          @adler = @wbits > 15 ? Zlib.crc32(s, @adler) : Zlib.adler32(s, @adler)
          @crc = Zlib.crc32(s, @crc)
          @in << s
          @total_in += s.bytesize
          @input_count += s.bytesize
          __pump(NO_FLUSH)
        end
      end
      self
    end

    def finish(&block)
      __ready
      @lock.synchronize do
        __pump(FINISH) unless @finished
        __drain(true, &block)
      end
    end

    def flush(flush = SYNC_FLUSH, &block)
      deflate('', flush, &block)
    end

    def params(level, strategy)
      __ready
      level = Integer(level)
      strategy = Integer(strategy)
      raise StreamError, 'stream error' unless (-1..9).include?(level) && (0..4).include?(strategy)
      @lock.synchronize do
        __pump(5) if @started && !@finished && !@in.empty?
        @level = level
        @strategy = strategy
      end
      nil
    end

    def set_dictionary(dict)
      __ready
      raise StreamError, 'stream error' if @started
      value = Zlib.__string(dict)
      @dictionary = true
      @history = (value.byteslice(-[1 << @window, value.bytesize].min, value.bytesize) || +'').b
      @dict_adler = Zlib.adler32(value)
      @adler = @dict_adler
      dict
    end

    # Input has been consumed into the compressor's bounded lookahead.
    def avail_in; __ready; 0; end
    def flush_next_in; __ready; +''.b; end
  end

  class Inflate < ZStream
    def initialize(window_bits = MAX_WBITS)
      @wbits = window_bits.nil? ? 15 : Integer(window_bits)
      unless @wbits == 0 || (8..15).include?(@wbits) || (-15..-8).include?(@wbits) || (24..31).include?(@wbits) || (40..47).include?(@wbits)
        raise StreamError, 'stream error'
      end
      __reset
    end

    def __reset
      __init_stream
      @state = +''.b
      @phase = @wbits < 0 ? :body : :header
      @format = @wbits < 0 ? :raw : :zlib
      @dictionaries ||= {}
      @dict_id = nil
      @crc = 0
      @size = 0
      @bad = false
      @sync_tail = +''.b
    end

    def initialize_copy(other)
      super
      @state = @state.dup
      @dictionaries = @dictionaries.dup
    end

    def self.inflate(str, &block)
      z = new
      begin
        out = z.inflate(str, &block)
        tail = z.finish(&block)
        block ? nil : out + tail
      ensure
        z.close unless z.closed?
      end
    end

    def __consume(n)
      s = @in.byteslice(0, n)
      @in = @in.byteslice(n, @in.bytesize - n)
      @total_in += n
      s
    end

    def __header
      return false if @in.bytesize < 2
      a = @in.getbyte(0)
      b = @in.getbyte(1)
      if a == 31 && b == 139 && @wbits > 15
        return false if @in.bytesize < 10
        raise DataError, 'unknown compression method' if @in.getbyte(2) != 8
        flags = @in.getbyte(3)
        raise DataError, 'unknown header flags set' if (flags & 224) != 0
        @gzip_mtime = @in.byteslice(4, 4).unpack1('V')
        @gzip_os = @in.getbyte(9)
        @gzip_level = @in.getbyte(8) == 2 ? 9 : (@in.getbyte(8) == 4 ? 1 : -1)
        pos = 10
        if (flags & 4) != 0
          return false if @in.bytesize < pos + 2
          n = @in.byteslice(pos, 2).unpack1('v')
          pos += 2 + n
          return false if @in.bytesize < pos
        end
        [8, 16].each do |mask|
          if (flags & mask) != 0
            term = @in.index("\0", pos)
            return false unless term
            if mask == 8
              @gzip_name = @in.byteslice(pos, term - pos)
            else
              @gzip_comment = @in.byteslice(pos, term - pos)
            end
            pos = term + 1
          end
        end
        if (flags & 2) != 0
          return false if @in.bytesize < pos + 2
          raise DataError, 'header crc mismatch' if (@in.byteslice(pos, 2).unpack1('v') != (Zlib.crc32(@in.byteslice(0, pos)) & 65535))
          pos += 2
        end
        __consume(pos)
        @format = :gzip
        @adler = 0
      else
        raise DataError, 'incorrect header check' if @wbits.between?(24, 31) || ((a << 8) + b) % 31 != 0
        raise DataError, 'unknown compression method' if (a & 15) != 8
        raise DataError, 'invalid window size' if (a >> 4) > 7 || (@wbits > 0 && @wbits <= 15 && (a >> 4) + 8 > @wbits)
        return false if (b & 32) != 0 && @in.bytesize < 6
        __consume(2)
        if (b & 32) != 0
          @dict_id = __consume(4).unpack1('N')
          @phase = :dictionary
          @adler = @dict_id
          dict = @dictionaries[@dict_id]
          if dict
            @history = dict.byteslice(-[32768, dict.bytesize].min, dict.bytesize) || +''.b
            @phase = :body
            @adler = 1
          else
            raise NeedDict, 'need dictionary'
          end
        end
      end
      @phase = :body unless @phase == :dictionary
      true
    end

    def __decode(target = nil)
      raise DataError, 'invalid compressed data -- format violated' if @bad
      loop do
        return if target && @out.bytesize >= target
        if @phase == :header
          return unless __header
        elsif @phase == :dictionary
          raise NeedDict, 'need dictionary'
        elsif @phase == :body
          @state, @history, data, used, status = Zlib.__inflate_step(@state, @history, @in.byteslice(0, 65536), 16384)
          __consume(used)
          @out << data
          @total_out += data.bytesize
          @size += data.bytesize
          @adler = @format == :gzip ? Zlib.crc32(data, @adler) : Zlib.adler32(data, @adler)
          if status < 0
            @bad = true
            raise DataError, 'invalid compressed data -- format violated'
          elsif status == 1
            @phase = :trailer
          elsif data.empty? && used == 0
            return
          end
        elsif @phase == :trailer
          n = @format == :gzip ? 8 : (@format == :zlib ? 4 : 0)
          return if @in.bytesize < n
          tail = __consume(n)
          if @format == :zlib
            raise DataError, 'incorrect data check' if tail.unpack1('N') != @adler
          elsif @format == :gzip
            crc, size = tail.unpack('V2')
            raise DataError, 'incorrect data check' if crc != @adler
            raise DataError, 'incorrect length check' if size != (@size & 0xffffffff)
          end
          @phase = :done
          @finished = true

          return
        else
          return
        end
      end
    end

    def inflate(str, buffer: nil, &block)
      __ready
      @lock.synchronize do
        if @finished
          @out << @in
          @in = +''.b
          @out << Zlib.__string(str).b unless str.nil?
          result = str.nil? ? __drain(true, &block) : +''.b
        else
          @in << Zlib.__string(str).b unless str.nil?
          if block
            loop do
              before = @total_in
              produced = @total_out
              __decode(16384)
              __drain(@finished) do |chunk|
                block.call(buffer ? buffer.replace(chunk) : chunk)
              end
              break if @finished || (before == @total_in && produced == @total_out)
            end
            result = nil
          else
            __decode
            result = __drain(@finished)
          end
          raise BufError, 'buffer error' if str.nil? && !@finished
          if @finished
            @out << @in
            @in = +''.b
          end
        end
        buffer && result ? buffer.replace(result) : result
      end
    end

    def <<(str)
      __ready
      @lock.synchronize do
        if @finished
          @out << @in
          @in = +''.b
          @out << Zlib.__string(str).b unless str.nil?
        else
          @in << Zlib.__string(str).b unless str.nil?
          __decode
          raise BufError, 'buffer error' if str.nil? && !@finished
        end
      end
      self
    end

    def finish(&block)
      __ready
      @lock.synchronize do
        __decode unless @finished
        raise BufError, 'buffer error' unless @finished
        @out << @in
        @in = +''.b
        __drain(true, &block)
      end
    end

    def set_dictionary(dict)
      __ready
      dict = Zlib.__string(dict).b
      unless @phase == :dictionary || @wbits < 0
        raise StreamError, 'stream error'
      end
      raise DataError, 'data error' if @dict_id && Zlib.adler32(dict) != @dict_id
      @history = dict.byteslice(-[32768, dict.bytesize].min, dict.bytesize) || +''.b
      @phase = :body
      @adler = 1
      dict
    end

    def add_dictionary(dict)
      __ready
      dict = Zlib.__string(dict).b
      @dictionaries[Zlib.adler32(dict)] = dict
      self
    end

    def sync(str)
      __ready
      @in << Zlib.__string(str).b
      marker = @in.index("\x00\x00\xff\xff".b)
      if marker
        __consume(marker + 4)
        @state = +''.b
        @history = +''.b
        @phase = :body
        @bad = false
        true
      else
        @in = @in.byteslice(-[3, @in.bytesize].min, @in.bytesize) || +''.b
        false
      end
    end

    def sync_point?; __ready; !@state.empty? && @state.unpack1('V') == 1; end
  end

  def self.deflate(str, level = DEFAULT_COMPRESSION, &block)
    Deflate.deflate(str, level, &block)
  end
  def self.inflate(str, &block)
    Inflate.inflate(str, &block)
  end
end
