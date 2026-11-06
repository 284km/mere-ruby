# frozen_string_literal: true
#
# Prism's C half, as mere-ruby answers `require "prism/prism"`.
#
# The reference's lib/prism.rb requires "prism/prism" -- the C extension
# (prism/extension.c), which builds the Prism::Node tree in C. mere-ruby
# cannot load a C extension; what it has instead is libprism itself
# (vendor/prism, Prism 1.8.2, the copy Ruby 4.0.9 ships) reached through
# five externs (tools/prism_glue.c), each returning the parser's SERIALIZED
# answer. Prism's own Ruby library reads that format (lib/prism/serialize.rb),
# which is exactly how its FFI backend (lib/prism/ffi.rb) works on other
# implementations; this file is that backend with Mere's bytes in place of
# FFI::MemoryPointer, and without the ffi gem.
#
# Prism.__prism_ser(kind, source, options) -> String   the serialized parse (0),
#                                                      lex (1), comments (2) or
#                                                      parse_lex (3)
# Prism.__prism_ok(source, options)        -> true/false  parse_success?
# Prism.__prism_more(source, options)      -> true/false  parse_stream's "read more"
# Prism.__prism_query(kind, s, encoding)   -> -1/0/1      StringQuery
# Prism.__prism_version                    -> String
#
# `options` is the packed string Prism's FFI backend builds (dump_options
# below, verbatim from ffi.rb), the format pm_options_read reads.

module Prism
  # The version constant is set by reading the result of calling pm_version.
  VERSION = Prism.__prism_version.freeze

  class << self
    # Mirror the Prism.dump API by using the serialization API.
    def dump(source, **options)
      dump_common(check_string(source), options)
    end

    # Mirror the Prism.dump_file API by using the serialization API.
    def dump_file(filepath, **options)
      options[:filepath] = filepath
      dump_common(read_file(filepath), options)
    end

    # Mirror the Prism.lex API by using the serialization API.
    def lex(code, **options)
      lex_common(check_string(code), options)
    end

    # Mirror the Prism.lex_file API by using the serialization API.
    def lex_file(filepath, **options)
      options[:filepath] = filepath
      lex_common(read_file(filepath), options)
    end

    # Mirror the Prism.parse API by using the serialization API.
    def parse(code, **options)
      parse_common(check_string(code), options)
    end

    # Mirror the Prism.parse_file API by using the serialization API.
    def parse_file(filepath, **options)
      options[:filepath] = filepath
      parse_common(read_file(filepath), options)
    end

    # Mirror the Prism.parse_stream API. pm_parse_stream reads the stream a
    # line at a time (gets(4095), as the extension's fgets callback does),
    # stops at an `__END__` line, parses, and reads on only while the parser
    # still wants more -- an unterminated string or regexp whose body holds
    # that `__END__`, or an unterminated heredoc (Prism.__prism_more). So
    # `__END__` outside a literal leaves the rest of the stream unread, as
    # DATA needs it to be.
    def parse_stream(stream, **options)
      packed = dump_options(options)
      source = +""
      eof = read_stream(stream, source)
      until eof || !Prism.__prism_more(source, packed)
        eof = read_stream(stream, source)
      end
      Prism.load(source, Prism.__prism_ser(0, source, packed), options.fetch(:freeze, false))
    end

    # Mirror the Prism.parse_comments API by using the serialization API.
    def parse_comments(code, **options)
      parse_comments_common(check_string(code), options)
    end

    # Mirror the Prism.parse_file_comments API by using the serialization
    # API.
    def parse_file_comments(filepath, **options)
      options[:filepath] = filepath
      parse_comments_common(read_file(filepath), options)
    end

    # Mirror the Prism.parse_lex API by using the serialization API.
    def parse_lex(code, **options)
      parse_lex_common(check_string(code), options)
    end

    # Mirror the Prism.parse_lex_file API by using the serialization API.
    def parse_lex_file(filepath, **options)
      options[:filepath] = filepath
      parse_lex_common(read_file(filepath), options)
    end

    # Mirror the Prism.parse_success? API by using the serialization API.
    def parse_success?(code, **options)
      Prism.__prism_ok(check_string(code), dump_options(options))
    end

    # Mirror the Prism.parse_failure? API by using the serialization API.
    def parse_failure?(code, **options)
      !parse_success?(code, **options)
    end

    # Mirror the Prism.parse_file_success? API by using the serialization API.
    def parse_file_success?(filepath, **options)
      options[:filepath] = filepath
      Prism.__prism_ok(read_file(filepath), dump_options(options))
    end

    # Mirror the Prism.parse_file_failure? API by using the serialization API.
    def parse_file_failure?(filepath, **options)
      !parse_file_success?(filepath, **options)
    end

    # Mirror the Prism.profile API by using the serialization API.
    def profile(source, **options)
      Prism.__prism_ser(0, check_string(source), dump_options(options))
      nil
    end

    # Mirror the Prism.profile_file API by using the serialization API.
    def profile_file(filepath, **options)
      options[:filepath] = filepath
      Prism.__prism_ser(0, read_file(filepath), dump_options(options))
      nil
    end

    private

    # The extension's check_string.
    def check_string(value)
      raise TypeError, "wrong argument type #{value.class} (expected String)" unless value.is_a?(String)
      value
    end

    # pm_string_mapped_init: the file's bytes; a directory is EISDIR and any
    # other failure its errno, raised as the extension raises it --
    # `SystemCallError.new(filepath, errno)`, whose message is
    # "No such file or directory - idontexist.rb" with no "@ rb_sysopen".
    def read_file(filepath)
      raise TypeError, "wrong argument type #{filepath.class} (expected String)" unless filepath.is_a?(String)
      File.binread(filepath)
    rescue SystemCallError => e
      raise SystemCallError.new(filepath, e.errno)
    end

    # pm_parse_stream_read: append lines until the stream ends (true) or an
    # `__END__` line has been appended (false). A 4095-byte piece is a line
    # longer than fgets' buffer, read on without the `__END__` check.
    def read_stream(stream, source)
      loop do
        line = stream.gets(4095)
        return true if line.nil?
        source << line
        next if line.bytesize == 4095
        case line
        when "__END__", "__END__\n", "__END__\r\n"
          return false
        end
        return true if stream.eof?
      end
    end

    def dump_common(string, options) # :nodoc:
      dumped = Prism.__prism_ser(0, string, dump_options(options))
      dumped.freeze if options.fetch(:freeze, false)
      dumped
    end

    def lex_common(code, options) # :nodoc:
      Serialize.load_lex(code, Prism.__prism_ser(1, code, dump_options(options)), options.fetch(:freeze, false))
    end

    def parse_common(code, options) # :nodoc:
      Serialize.load_parse(code, dump_common(code, options), options.fetch(:freeze, false))
    end

    def parse_comments_common(code, options) # :nodoc:
      Serialize.load_parse_comments(code, Prism.__prism_ser(2, code, dump_options(options)), options.fetch(:freeze, false))
    end

    def parse_lex_common(code, options) # :nodoc:
      Serialize.load_parse_lex(code, Prism.__prism_ser(3, code, dump_options(options)), options.fetch(:freeze, false))
    end

    # Return the value that should be dumped for the command_line option.
    def dump_options_command_line(options)
      command_line = options.fetch(:command_line, "")
      raise ArgumentError, "command_line must be a string" unless command_line.is_a?(String)

      command_line.each_char.inject(0) do |value, char|
        case char
        when "a" then value | 0b000001
        when "e" then value | 0b000010
        when "l" then value | 0b000100
        when "n" then value | 0b001000
        when "p" then value | 0b010000
        when "x" then value | 0b100000
        else raise ArgumentError, "invalid command_line option: #{char}"
        end
      end
    end

    # Return the value that should be dumped for the version option.
    def dump_options_version(version)
      current = version == "current"

      case current ? RUBY_VERSION : version
      when nil, "latest"
        0 # Handled in pm_parser_init
      when /\A3\.3(\.\d+)?\z/
        1
      when /\A3\.4(\.\d+)?\z/
        2
      when /\A3\.5(\.\d+)?\z/, /\A4\.0(\.\d+)?\z/
        3
      when /\A4\.1(\.\d+)?\z/
        4
      else
        if current
          raise CurrentVersionError, RUBY_VERSION
        else
          raise ArgumentError, "invalid version: #{version}"
        end
      end
    end

    # Convert the given options into a serialized options string.
    def dump_options(options)
      template = +""
      values = []

      template << "L"
      if (filepath = options[:filepath])
        values.push(filepath.bytesize, filepath.b)
        template << "A*"
      else
        values << 0
      end

      template << "l"
      values << options.fetch(:line, 1)

      template << "L"
      if (encoding = options[:encoding])
        name = encoding.is_a?(Encoding) ? encoding.name : encoding
        values.push(name.bytesize, name.b)
        template << "A*"
      else
        values << 0
      end

      template << "C"
      values << (options.fetch(:frozen_string_literal, false) ? 1 : 0)

      template << "C"
      values << dump_options_command_line(options)

      template << "C"
      values << dump_options_version(options[:version])

      template << "C"
      values << (options[:encoding] == false ? 1 : 0)

      template << "C"
      values << (options.fetch(:main_script, false) ? 1 : 0)

      template << "C"
      values << (options.fetch(:partial_script, false) ? 1 : 0)

      template << "C"
      values << (options.fetch(:freeze, false) ? 1 : 0)

      template << "L"
      if (scopes = options[:scopes])
        values << scopes.length

        scopes.each do |scope|
          locals = nil
          forwarding = 0

          case scope
          when Array
            locals = scope
          when Scope
            locals = scope.locals

            scope.forwarding.each do |forward|
              case forward
              when :*     then forwarding |= 0x1
              when :**    then forwarding |= 0x2
              when :&     then forwarding |= 0x4
              when :"..." then forwarding |= 0x8
              else raise ArgumentError, "invalid forwarding value: #{forward}"
              end
            end
          else
            raise TypeError, "wrong argument type #{scope.class.inspect} (expected Array or Prism::Scope)"
          end

          template << "L"
          values << locals.length

          template << "C"
          values << forwarding

          locals.each do |local|
            name = local.name
            template << "L"
            values << name.bytesize

            template << "A*"
            values << name.b
          end
        end
      else
        values << 0
      end

      values.pack(template)
    end
  end

  # The class-level methods the extension puts on StringQuery (the instance
  # side is prism/string_query.rb, autoloaded by prism.rb).
  class StringQuery
    class << self
      # Mirrors the C extension's StringQuery::local? method.
      def local?(string)
        query(0, string)
      end

      # Mirrors the C extension's StringQuery::constant? method.
      def constant?(string)
        query(1, string)
      end

      # Mirrors the C extension's StringQuery::method_name? method.
      def method_name?(string)
        query(2, string)
      end

      private

      # Ask libprism and turn its enum into the boolean or the error.
      def query(kind, string)
        raise TypeError, "wrong argument type #{string.class} (expected String)" unless string.is_a?(String)

        case Prism.__prism_query(kind, string, string.encoding.name)
        when -1
          raise ArgumentError, "Invalid or non ascii-compatible encoding"
        when 0
          false
        else
          true
        end
      end
    end
  end
end
