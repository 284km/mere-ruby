# (frozen string literals: tools/gen_psych_lib.rb puts the magic comment at the
#  top of the embedded source. An empty scalar's value is +'', as libyaml's is
#  not frozen.)
# YAML event parsing has its own state; loading Ruby objects is a separate visitor.
module Psych
  class SyntaxError < Exception
    attr_reader :file, :line, :column, :offset, :problem, :context
    def initialize(file, line, column, offset, problem, context)
      @file, @line, @column, @offset = file, line, column, offset
      @problem, @context = problem, context
      super("(#{file || '<unknown>'}): #{[problem, context].compact.join(' ')} at line #{line} column #{column}")
    end
  end

  class Parser
    ANY = 0
    UTF8 = 1
    UTF16LE = 2
    UTF16BE = 3
    Mark = Struct.new(:index, :line, :column)
    ESCAPES = {'0' => "\0", 'a' => "\a", 'b' => "\b", 't' => "\t", 'n' => "\n", 'v' => "\v", 'f' => "\f", 'r' => "\r", 'e' => "\e", ' ' => ' ', '"' => '"', '/' => '/', '\\' => '\\', 'N' => "\u0085", '_' => "\u00a0", 'L' => "\u2028", 'P' => "\u2029"}.freeze
    PLAIN_BREAKS = [':', "\r", "\n", '#'].freeze
    FLOW_BREAKS = [':', "\r", "\n", '#', ',', '[', ']', '{', '}'].freeze
    SINGLE_BREAKS = ["'", "\n"].freeze
    DOUBLE_BREAKS = ['"', '\\', "\n"].freeze
    # The scanner reads BYTES (Integers): the syntax of YAML is ASCII, and a
    # one-byte String per character read was most of what a load made -- about
    # 110 Strings a row of activerecord's citations fixture, 6 of them kept.
    # What a token holds is cut from the source by byte position, as before.
    PUNCTUATION = {91 => [:sequence, '['], 93 => [:sequence_end, ']'], 123 => [:mapping, '{'],
                   125 => [:mapping_end, '}'], 44 => [:comma, ',']}.freeze
    INDICATORS = {45 => [:entry, '-'], 63 => [:key, '?'], 58 => [:value, ':']}.freeze
    BYTE_ESCAPES = ESCAPES.to_h { |k, v| [k.ord, v.b] }.freeze
    HEX_ESCAPES = {120 => 2, 117 => 4, 85 => 8}.freeze
    DOCUMENT_ENDS = [:eof, :document, :end_document].freeze
    PROPERTIES = [:anchor, :tag].freeze
    KEY_KINDS = [:scalar, :alias, :sequence, :mapping].freeze
    OPENERS = [:sequence, :mapping].freeze
    CLOSERS = [:sequence_end, :mapping_end].freeze
    DOCUMENT_MARKS = ['---', '...'].freeze
    private_constant :ESCAPES, :PLAIN_BREAKS, :FLOW_BREAKS, :SINGLE_BREAKS, :DOUBLE_BREAKS,
                     :PUNCTUATION, :INDICATORS, :BYTE_ESCAPES, :HEX_ESCAPES, :DOCUMENT_ENDS,
                     :PROPERTIES, :KEY_KINDS, :OPENERS, :CLOSERS, :DOCUMENT_MARKS
    attr_accessor :handler
    attr_writer :external_encoding

    def initialize(handler = Handler.new)
      @handler = handler
      @external_encoding = ANY
      @mark_indices = [0, 0, 0]
    end

    def mark
      Mark.new(*@mark_indices)
    end

    def parse(yaml, path = yaml.respond_to?(:path) ? yaml.path : '<unknown>')
      @path, @line, @column = path, 0, 0
      if yaml.respond_to?(:read)
        chunks = []
        while (chunk = yaml.read(16384))
          chunk = __string(chunk)
          break if chunk.empty?
          chunks << chunk.b
        end
        source = chunks.join.b
      else
        source = __string(yaml).dup
      end
      encoding = @external_encoding
      if encoding == UTF16LE || encoding == UTF16BE
        source.force_encoding(encoding == UTF16LE ? 'UTF-16LE' : 'UTF-16BE')
      elsif yaml.respond_to?(:read) || source.encoding == Encoding::ASCII_8BIT
        bytes = source.byteslice(0, 4).bytes
        if bytes[0, 2] == [255, 254] || (bytes[1] == 0 && bytes[3] == 0)
          source.force_encoding('UTF-16LE')
        elsif bytes[0, 2] == [254, 255] || (bytes[0] == 0 && bytes[2] == 0)
          source.force_encoding('UTF-16BE')
        else
          source.force_encoding('UTF-8')
        end
      end
      __error('invalid leading UTF-8 octet') unless source.valid_encoding?
      stream_encoding = case source.encoding.name
        when 'UTF-16LE' then UTF16LE
        when 'UTF-16BE' then UTF16BE
        else UTF8
      end
      source = source.encode('UTF-8') unless source.encoding == Encoding::UTF_8
      # The pinned parser skips a BOM as one character in its location marks.
      bom_offset = source.start_with?("\uFEFF") ? 1 : 0
      source = source.sub(/\A\uFEFF/, '')
      if (invalid = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.match(source))
        prefix = source[0, invalid.begin(0)].split("\n", -1)
        raise SyntaxError.new(path, [prefix.length, 1].max, (prefix.last || '').length + 1, 0, 'control characters are not allowed', nil)
      end
      # (an ASCII-only source has one character per byte: a run's length is
      #  its byte count, with no String cut out to count it -- __skip)
      @ascii = source.ascii_only?
      @source, @path, @pos = source.b, path, 0
      @length = @source.bytesize
      @window_start = 0
      @window = @source.byteslice(0, 65536)
      @window_end = @window.bytesize
      @index = bom_offset
      @line, @column, @flow = 0, bom_offset, 0
      @line_content = false
      @block_indent = -1
      @tokens = []
      @special_positions = {}
      @mark_indices = [0, 0, 0]
      @tag_handles = {'!!' => 'tag:yaml.org,2002:', '!' => '!'}
      __event(:start_stream, [stream_encoding], [0, 0, 0], [0, 0, 0])
      __space
      until __peek[0] == :eof
        @block_indent = -1
        version, tags = [], []
        start = __peek[2]
        while __peek[0] == :directive
          directive = __take
          text = directive[1].split
          if text[0] == '%YAML'
            __error('found incompatible YAML document') unless text[1] =~ /\A1\.[12]\z/
            version = text[1].split('.').map(&:to_i)
          elsif text[0] == '%TAG'
            __error('did not find expected tag directive') unless text.size == 3
            tags << text[1, 2]
            @tag_handles[text[1]] = text[2]
          end
        end
        explicit = __peek[0] == :document
        ending = explicit ? __take[3] : __peek[2]
        __error("did not find expected <document start>") if (!version.empty? || !tags.empty?) && !explicit
        __event(:start_document, [version, tags, !explicit], start, ending)
        if DOCUMENT_ENDS.include?(__peek[0])
          __empty(__peek[2])
        else
          __node(-1)
        end
        token = __peek
        unless DOCUMENT_ENDS.include?(token[0])
          # libyaml ends the document (implicitly) before it looks for the
          # start of the next one, so a handler has this document whole --
          # Psych.parse returns from its block there -- and only then is what
          # follows it an error.
          __event(:end_document, [true], token[2], token[2])
          __error("did not find expected <document start>")
        end
        explicit_end = token[0] == :end_document
        end_start = token[2]
        end_finish = explicit_end ? __take[3] : end_start
        __event(:end_document, [!explicit_end], end_start, end_finish)
        @tag_handles = {'!!' => 'tag:yaml.org,2002:', '!' => '!'}
      end
      finish = __peek[2]
      __event(:end_stream, [], finish, finish)
      self
    ensure
      @source = nil
      @window = nil
      @tokens = nil
    end

    private

    # [index, line, column] counts Unicode characters, as libyaml marks do.
    def __at
      [@index, @line, @column]
    end

    def __string(value)
      return value if value.is_a?(String)
      if value.respond_to?(:to_str)
        converted = value.to_str
        return converted if converted.is_a?(String)
      end
      raise TypeError, 'no implicit conversion into String'
    end

    def __error(problem, mark = nil, context = 'while parsing a node')
      mark ||= [0, @line, @column]
      raise SyntaxError.new(@path, mark[1] + 1, mark[2] + 1, 0, problem, context)
    end

    # Keep hot byte reads on a small source window. Repeated VM operations on
    # a multi-megabyte String otherwise promote that entire value repeatedly.
    def __byte(position)
      return nil if position < 0 || position >= @length
      if position < @window_start || position >= @window_end
        @window_start = position
        @window = @source.byteslice(position, 65536)
        @window_end = position + @window.bytesize
      end
      @window.getbyte(position - @window_start)
    end

    # (what /\s/ matched on a one-character String: \f and \v never reach the
    #  scanner, parse refuses them as control characters)
    def __blank?(byte)
      byte == 32 || byte == 10 || byte == 9 || byte == 13
    end

    # A-Z a-z 0-9 _ -
    def __name_byte?(byte)
      (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 95 || byte == 45
    end

    # , [ ] { }
    def __flow_indicator?(byte)
      byte == 44 || byte == 91 || byte == 93 || byte == 123 || byte == 125
    end

    def __slice(position, count)
      if position >= @window_start && position + count <= @window_end
        @window.byteslice(position - @window_start, count)
      else
        @source.byteslice(position, count)
      end
    end

    def __index(character, from = @pos)
      cursor = from
      while cursor < @length
        if cursor >= @window_start && cursor < @window_end
          at = @window.index(character, cursor - @window_start)
          return @window_start + at if at
          cursor = @window_end
        else
          text = @source.byteslice(cursor, 65536)
          at = text.index(character)
          return cursor + at if at
          cursor += text.bytesize
        end
      end
      nil
    end

    # One character's first byte on, counted as libyaml counts its marks: a
    # line at "\n", and a column and an index per character (a UTF-8
    # continuation byte, 128..191, is not one). Answers the byte.
    def __advance
      byte = __byte(@pos)
      __error('found unexpected end of stream') unless byte
      @pos += 1
      if byte == 10
        @line += 1
        @column = 0
        @line_content = false
      elsif byte < 128 || byte >= 192
        @column += 1
      end
      @index += 1 if byte < 128 || byte >= 192
      @line_content = true unless __blank?(byte)
      byte
    end

    # Skip a run without line breaks in one operation. A character loop makes
    # large scalars spend most of their time allocating transient Ruby strings.
    def __skip(finish)
      count = @ascii ? finish - @pos : __slice(@pos, finish - @pos).force_encoding('UTF-8').length
      @index += count
      @column += count
      @line_content = true if finish > @pos
      @pos = finish
    end

    # Cache each delimiter's next occurrence. Searching with Regexp here
    # interleaves large and small subjects and defeats the VM's snapshot cache.
    def __separator(characters)
      finish = @length
      characters.each do |character|
        at = @special_positions[character]
        if at.nil? || at < @pos
          at = __index(character, @pos) || @length
          @special_positions[character] = at
        end
        finish = at if at < finish
      end
      finish
    end

    def __space
      loop do
        c = __byte(@pos)
        __error('found character that cannot start any token', nil, 'while scanning for the next token') if c == 9 && !@line_content
        if __blank?(c)
          __advance
        elsif c == 35
          __skip(__index("\n", @pos) || @length)
        else
          break
        end
      end
    end

    def __peek(n = 0)
      @tokens << __scan while @tokens.length <= n
      @tokens[n]
    end

    def __take
      __peek
      @tokens.shift
    end

    def __event(name, args, start, finish, current = finish)
      @mark_indices = current
      @handler.event_location(start[1], start[2], finish[1], finish[2])
      if Encoding.default_internal
        convert = lambda { |v| v.is_a?(String) ? v.encode(Encoding.default_internal) : (v.is_a?(Array) ? v.map(&convert) : v) }
        args = args.map(&convert)
      end
      @handler.send(name, *args)
    end

    def __empty(at, anchor = nil, tag = nil)
      __event(:scalar, [+'', anchor, tag, tag.nil?, false, 1], at, at)
    end

    def __scan
      __space
      start = __at
      c = __byte(@pos)
      unless c
        start = [@index, @column == 0 ? @line : @line + 1, 0]
        return [:eof, nil, start, start, nil]
      end
      if @column == 0 && c == 37
        from = @pos
        __skip(__index("\n", @pos) || @length)
        return [:directive, __slice(from, @pos - from).force_encoding('UTF-8'), start, __at, nil]
      end
      if @column == 0 && (c == 45 || c == 46)
        head = __slice(@pos, 3)
        if (head == '---' || head == '...') && (__byte(@pos + 3).nil? || __blank?(__byte(@pos + 3)))
          3.times { __advance }
          return [head == '---' ? :document : :end_document, nil, start, __at, nil]
        end
      end
      if (punctuation = PUNCTUATION[c])
        __advance
        @flow += 1 if c == 91 || c == 123
        @flow -= 1 if c == 93 || c == 125
        return [punctuation[0], punctuation[1], start, __at, nil]
      end
      if (indicator = INDICATORS[c])
        following = __byte(@pos + 1)
        if following.nil? || __blank?(following) || (@flow > 0 && c == 58)
          __advance
          return [indicator[0], indicator[1], start, __at, nil]
        end
      end
      if c == 38 || c == 42
        # (libyaml's name: letters, digits, '_' and '-', ended by a blank or
        #  one of ? : , ] } % @ ` -- anything else is an error at the & or *)
        __advance
        from = @pos
        __advance while (b = __byte(@pos)) && __name_byte?(b)
        following = __byte(@pos)
        if @pos == from || !(following.nil? || __blank?(following) || following == 63 || following == 58 ||
                             following == 44 || following == 93 || following == 125 || following == 37 ||
                             following == 64 || following == 96)
          __error('did not find expected alphabetic or numeric character', start,
                  c == 38 ? 'while scanning an anchor' : 'while scanning an alias')
        end
        return [c == 38 ? :anchor : :alias, __slice(from, @pos - from).force_encoding('UTF-8'), start, __at, nil]
      end
      if c == 33
        if __byte(@pos + 1) == 60
          2.times { __advance }
          from = @pos
          __advance while @pos < @length && __byte(@pos) != 62
          value = __slice(from, @pos - from)
          __error('did not find expected >') unless __byte(@pos) == 62
          __advance
        else
          from = @pos
          while @pos < @length && !(__blank?(__byte(@pos)) || __flow_indicator?(__byte(@pos)))
            __advance
          end
          value = __slice(from, @pos - from)
          if (m = /\A(![^!]*!)(.*)\z/.match(value))
            __error('found undefined tag handle') unless @tag_handles.key?(m[1])
            value = @tag_handles[m[1]] + m[2]
          elsif value != '!'
            value = @tag_handles['!'] + value[1..]
          end
        end
        return [:tag, value.force_encoding('UTF-8'), start, __at, nil]
      end
      if c == 39 || c == 34
        quote = __advance
        value = []
        closed = false
        while @pos < @length
          finish = __separator(quote == 39 ? SINGLE_BREAKS : DOUBLE_BREAKS)
          if finish > @pos
            value << __slice(@pos, finish - @pos)
            __skip(finish)
            next
          end
          c = __advance
          if c == quote
            if quote == 39 && __byte(@pos) == 39
              __advance
              value << "'"
              next
            end
            closed = true
            break
          elsif c == 92 && quote == 34
            escape = __advance
            if (count = HEX_ESCAPES[escape])
              hex = __slice(@pos, count)
              __error('did not find expected hexadecimal number') unless hex && hex.length == count && hex =~ /\A[0-9a-fA-F]+\z/
              count.times { __advance }
              begin
                value << [hex.to_i(16)].pack('U').b
              rescue RangeError
                __error('found invalid Unicode character escape code')
              end
            elsif escape == 10
              __advance while __byte(@pos) == 32 || __byte(@pos) == 9
            elsif (text = BYTE_ESCAPES[escape])
              value << text
            else
              __error('found unknown escape character')
            end
          elsif c == 10
            value[-1] = value.last.rstrip unless value.empty?
            count = 0
            while __byte(@pos) == 32 || __byte(@pos) == 9 || __byte(@pos) == 10
              count += 1 if __advance == 10
            end
            value << (count == 0 ? ' ' : "\n" * count)
          else
            value << c.chr
          end
        end
        __error('found unexpected end of stream', start, 'while scanning a quoted scalar') unless closed
        return [:scalar, value.join.force_encoding('UTF-8'), start, __at, quote == 39 ? 2 : 3]
      end
      if c == 124 || c == 62
        style = __advance == 124 ? 4 : 5
        from = @pos
        while (m = __byte(@pos)) && (m == 45 || m == 43 || (m >= 49 && m <= 57))
          __advance
        end
        modifiers = __slice(from, @pos - from)
        __advance while __byte(@pos) == 32
        if __byte(@pos) == 35
          __advance while __byte(@pos) && __byte(@pos) != 10
        end
        # (a CRLF is one line break, as libyaml reads it)
        __advance if __byte(@pos) == 13 && __byte(@pos + 1) == 10
        __error('did not find expected comment or line break') unless __byte(@pos).nil? || __byte(@pos) == 10
        __advance if __byte(@pos) == 10
        lines = []
        indent = modifiers[/[1-9]/]&.to_i
        # Explicit indentation is relative to the enclosing block, not '|'.
        indent += [@block_indent || 0, 0].max if indent
        loop do
          break if @pos >= @length
          p = @pos
          p += 1 while __byte(p) == 32
          width = p - @pos
          blank = __byte(p).nil? || __byte(p) == 10 || __byte(p) == 13
          indent ||= width unless blank
          break if !blank && (width < indent || width <= (@block_indent || -1))
          width.times { __advance }
          body_start = @pos
          __skip(__index("\n", @pos) || @length)
          body_end = @pos
          body_end -= 1 if body_end > body_start && __byte(body_end - 1) == 13 && __byte(body_end) == 10
          body = __slice(body_start, body_end - body_start).force_encoding('UTF-8')
          body = (' ' * [width - (indent || width), 0].max) + body unless blank
          newline = __byte(@pos) == 10
          __advance if newline
          lines << [body, newline]
        end
        value = []
        n = 0
        while n < lines.length
          body, newline = lines[n]
          value << body
          count = newline ? 1 : 0
          following = n + 1
          while following < lines.length && lines[following][0].empty?
            count += 1 if lines[following][1]
            following += 1
          end
          next_body = lines[following]&.first
          if style == 5 && !body.empty? && next_body && !body.start_with?(' ') && !next_body.start_with?(' ')
            value << (count == 1 ? ' ' : "\n" * [count - 1, 0].max)
          else
            value << "\n" * count
          end
          n = following
        end
        value = value.join
        value = value.sub(/\n*\z/, '') if modifiers.include?('-')
        value = value.sub(/\n*\z/, "\n") unless modifiers.include?('-') || modifiers.include?('+') || value.empty?
        value = +'' if !modifiers.include?('+') && lines.all? { |body, _| body.empty? }
        return [:scalar, value, start, __at, style]
      end
      __error('found character that cannot start any token', nil, 'while scanning for the next token') if c == 96 || c == 64 || c == 37 || c == 9
      parts = []
      part_start = @pos
      while @pos < @length
        finish = __separator(@flow > 0 ? FLOW_BREAKS : PLAIN_BREAKS)
        if finish > @pos
          __skip(finish)
          next
        end
        c = __byte(@pos)
        if c == 10 || c == 13
          p = @pos
          breaks = 0
          line_start = p
          while (b = __byte(p)) && __blank?(b)
            if b == 10
              breaks += 1
              line_start = p + 1
            end
            p += 1
          end
          indentation = p - line_start
          following = __byte(p)
          break if !following || (@flow == 0 && indentation <= @block_indent) || following == 35 ||
                   (indentation == 0 && (following == 45 || following == 46) && DOCUMENT_MARKS.include?(__slice(p, 3)))
          __advance while @pos < p
          parts << __slice(part_start, @pos - part_start).rstrip
          parts << (breaks > 1 ? "\n" * (breaks - 1) : ' ')
          part_start = @pos
          next
        end
        break if @flow > 0 && __flow_indicator?(c)
        following = __byte(@pos + 1)
        break if c == 58 && (following.nil? || __blank?(following) || (@flow > 0 && __flow_indicator?(following)))
        break if c == 35 && (@pos == part_start || __blank?(__byte(@pos - 1)))
        __advance
      end
      last = __slice(part_start, @pos - part_start)
      value = (parts.empty? ? last : (parts << last).join).force_encoding('UTF-8')
      __error('did not find expected node content') if value.empty?
      # (a copy only when there is a blank to trim)
      trimmed = __blank?(value.getbyte(value.bytesize - 1)) ? value.rstrip : value
      finish = [@index - value.length + trimmed.length, @line, @column - value.length + trimmed.length]
      [:scalar, trimmed, start, finish, 1]
    end

    def __node(parent_indent, allow_mapping = true, indentless = false)
      token = __peek
      start = token[2]
      if allow_mapping && __mapping_key?
        return __block_map(start[2], start)
      end
      anchor = tag = nil
      property_end = nil
      while token[0] == :anchor || token[0] == :tag
        token[0] == :anchor ? anchor = token[1] : tag = token[1]
        property_end = token[3]
        __take
        token = __peek
      end
      if property_end && (DOCUMENT_ENDS.include?(token[0]) || (token[2][1] > property_end[1] && token[2][2] <= parent_indent && !(indentless && token[0] == :entry && token[2][2] == parent_indent)))
        return __event(:scalar, [+'', anchor, tag, tag.nil?, false, 1], start, property_end)
      end
      if token[0] == :sequence || token[0] == :mapping
        opener = __take
        sequence = opener[0] == :sequence
        name = sequence ? :sequence : :mapping
        ending = sequence ? :sequence_end : :mapping_end
        __event(sequence ? :start_sequence : :start_mapping, [anchor, tag, tag.nil?, 2], start, opener[3])
        first = true
        until __peek[0] == ending
          if __peek[0] == :eof
            if first
              __error('did not find expected node content', __peek[2], 'while parsing a flow node')
            else
              __error(sequence ? "did not find expected ',' or ']'" : "did not find expected ',' or '}'", start, sequence ? 'while parsing a flow sequence' : 'while parsing a flow mapping')
            end
          end
          if !first
            __error("did not find expected ',' or flow collection end") unless __peek[0] == :comma
            __take
            break if __peek[0] == ending
          end
          first = false
          if sequence && __mapping_key?
            __flow_pair(parent_indent, ending)
          else
            __take if __peek[0] == :key
            __peek[0] == :value ? __empty(__peek[2]) : __node(parent_indent, false)
          end
          unless sequence
            if __peek[0] == :value
              colon = __take
              [:comma, ending].include?(__peek[0]) ? __empty(colon[3]) : __node(parent_indent, false)
            else
              __empty(__peek[2])
            end
          end
        end
        close = __take
        __event(sequence ? :end_sequence : :end_mapping, [], close[2], close[3])
      elsif token[0] == :entry
        indent = token[2][2]
        finish = parent_indent == indent ? token[3] : token[2]
        __event(:start_sequence, [anchor, tag, tag.nil?, 1], start, finish, token[3])
        while __peek[0] == :entry && __peek[2][2] == indent
          entry = __take
          @block_indent = indent
          following = __peek
          if DOCUMENT_ENDS.include?(following[0]) || (following[2][1] > entry[2][1] && following[2][2] <= indent)
            __empty(entry[3])
          else
            __node(indent)
          end
        end
        at = __peek[2]
        __event(:end_sequence, [], at, at)
      elsif allow_mapping && __mapping_key?
        __block_map(token[2][2], start, anchor, tag)
      elsif token[0] == :alias
        __take
        __event(:alias, [token[1]], start, token[3])
      elsif token[0] == :scalar
        __take
        plain = token[4] == 1
        __space if @tokens.empty?
        current = @tokens.empty? ? __at : @tokens.first[2]
        current = [@index, @column == 0 ? @line : @line + 1, 0] if @pos == @length
        __event(:scalar, [token[1], anchor, tag, plain && tag.nil?, !plain && tag.nil?, token[4]], start, token[3], current)
      elsif anchor || tag
        __empty(token[2], anchor, tag)
      else
        __error('did not find expected node content')
      end
    end

    def __mapping_key?
      return true if __peek[0] == :key
      index = 0
      while PROPERTIES.include?(__peek(index)[0])
        index += 1
      end
      # Properties on their own line apply to the enclosing collection.
      return false if index > 0 && __peek(index)[2][1] != __peek[2][1]
      kind = __peek(index)[0]
      return false unless KEY_KINDS.include?(kind)
      if kind == :sequence || kind == :mapping
        depth = 0
        loop do
          current = __peek(index)[0]
          depth += 1 if OPENERS.include?(current)
          depth -= 1 if CLOSERS.include?(current)
          return false if current == :eof
          break if depth == 0
          index += 1
        end
      end
      __peek(index + 1)[0] == :value && __peek(index + 1)[2][1] == __peek(index)[3][1]
    end

    def __flow_pair(parent_indent, ending)
      start = __peek[2]
      __event(:start_mapping, [nil, nil, true, 2], start, start)
      __take if __peek[0] == :key
      __peek[0] == :value ? __empty(__peek[2]) : __node(parent_indent, false)
      if __peek[0] == :value
        colon = __take
        [:comma, ending].include?(__peek[0]) ? __empty(colon[3]) : __node(parent_indent, false)
      else
        __empty(__peek[2])
      end
      finish = __peek[2]
      __event(:end_mapping, [], finish, finish)
    end

    def __block_map(indent, start, anchor = nil, tag = nil)
      __event(:start_mapping, [anchor, tag, tag.nil?, 1], start, __peek[2])
      loop do
        key = __peek
        break if DOCUMENT_ENDS.include?(key[0]) || key[2][2] != indent
        explicit_key = key[0] == :key
        __error('did not find expected key') if key[0] == :value
        __take if explicit_key
        __peek[0] == :value ? __empty(__peek[2]) : __node(indent, false)
        colon = __peek
        if colon[0] == :value
          __take
          @block_indent = indent
          following = __peek
          if DOCUMENT_ENDS.include?(following[0]) || (following[2][1] > colon[2][1] && (following[2][2] < indent || (following[2][2] == indent && following[0] != :entry)))
            __empty(colon[3])
          else
            __node(indent, true, true)
          end
        elsif explicit_key
          __empty(colon[2])
        else
          __error("could not find expected ':'")
        end
      end
      at = __peek[2]
      __event(:end_mapping, [], at, at)
    end
  end
end
