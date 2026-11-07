# frozen_string_literal: true
#
# Ripper, as mere-ruby answers `require "ripper"` (and "ripper.so",
# "ripper/core", "ripper/lexer", "ripper/filter", "ripper/sexp": every name
# the reference's files are required by).
#
# The reference's Ripper is parse.y with event callbacks (ext/ripper, a C
# extension). What mere-ruby has is Prism (vendor/prism, through
# lib/prism_ext.rb), and Prism ships Prism::Translation::Ripper: Ripper's
# API over Prism's tree -- the parser events dispatched by walking the tree,
# the scanner's tokens from Prism.lex_compat (Ripper.lex's format, states
# included), SexpBuilder and SexpBuilderPP. That class IS ::Ripper here, as
# it is on TruffleRuby. Prism documents the known difference: some scanner
# events are not dispatched during #parse (on_sp, on_nl, on_kw, on_op...).
#
# What the translation does not carry is the Ruby half the reference layers
# on its C core -- ripper/lexer.rb's Lexer (tokenize / lex / scan, Elem,
# TokenPattern, Ripper.slice), ripper/filter.rb -- and the C core's few
# plain methods (dedent_string, end_seen?, encoding, yydebug, token). Those
# are here, Lexer over Prism.lex_compat instead of over scanner events.
# Elem, TokenPattern and Filter are ripper's own Ruby (Minero Aoki, Ruby's
# license), transcribed.

require "prism"
# (the translation and its Lexer / SexpBuilder are autoloaded constants;
#  required by name so that reopening them below reopens, not defines)
require "prism/translation/ripper"
require "prism/translation/ripper/lexer"
require "prism/translation/ripper/sexp"

unless defined?(::Ripper)
  # (reopened by its own name: the additions go on the translation class,
  #  and ::Ripper is bound to it below)
  class Prism::Translation::Ripper
    Version = "0.1.0"

    attr_reader :filename unless method_defined?(:filename)

    # The C core keeps its own copy of the filename (`filename.clear` after
    # Ripper.new leaves #filename as it was); the translation kept the
    # caller's String.
    alias __translation_initialize initialize
    def initialize(source, filename = "(ripper)", lineno = 1)
      # (the C core reads any object that answers #gets, line by line, when
      #  the parse runs -- a line that is no String is its TypeError then)
      @__input = nil
      unless source.is_a?(String)
        raise TypeError, "wrong argument type #{source.class} (expected String)" unless source.respond_to?(:gets)
        @__input = source
        source = ""
      end
      __translation_initialize(source, filename.is_a?(String) ? filename.dup.freeze : filename, lineno)
      @__parsing = false
    end

    # The source, read from the #gets object on first use.
    def source
      if @__input
        input, @__input = @__input, nil
        buf = +""
        while (line = input.gets)
          raise TypeError, "wrong argument type #{line.class} (expected String)" unless line.is_a?(String)
          buf << line
        end
        @source = buf
      end
      @source
    end

    # The C core's parser-state readers answer nil outside a parse. The
    # translation keeps @lineno and @column for its own walk; outside #parse
    # they are not the parser's position.
    def lineno
      @__parsing ? @lineno : nil
    end

    def column
      @__parsing ? @column : nil
    end

    # The lexer state at the current token: the translation has no lexer
    # running while it walks the tree.
    def state
      nil
    end

    # The current token: the same.
    def token
      nil
    end

    alias __translation_parse parse
    def parse
      @__parsing = true
      __yydebug_trace if @yydebug && @debug_output
      __translation_parse
    ensure
      @__parsing = false
    end

    # The C core's yydebug is bison's trace on debug_output: one "Next token
    # is token ..." line per token, named as parse.y names it, with its
    # location. The names test_ripper reads are given; the rest keep the
    # scanner event's.
    YYDEBUG_TOKEN_NAMES = {
      on_ident: "local variable or method", on_tstring_content: "literal content",
      on_int: "integer literal", on_float: "float literal", on_const: "constant",
      on_ivar: "instance variable", on_gvar: "global variable", on_cvar: "class variable",
      on_tstring_beg: "string literal", on_kw: "keyword", on_op: "operator",
    }.freeze
    YYDEBUG_NAMED_TOKENS = %i[on_ident on_const on_ivar on_gvar on_cvar on_int on_float on_kw on_op].freeze
    private_constant :YYDEBUG_TOKEN_NAMES, :YYDEBUG_NAMED_TOKENS

    def __yydebug_trace
      Lexer.new(result.source.source, @filename, @lineno).lex.each do |(pos, event, tok, _state)|
        next if event == :on_sp || event == :on_nl || event == :on_ignored_nl
        name = YYDEBUG_TOKEN_NAMES[event] || event.to_s.delete_prefix("on_")
        line, col = pos
        # (bison prints a name's text, and nothing for a literal's content)
        text = YYDEBUG_NAMED_TOKENS.include?(event) ? tok : ""
        loc = "(#{line}.#{col}-#{line}.#{col + tok.length}: #{text})"
        @debug_output << "Next token is token \"#{name}\" #{loc}\n"
        @debug_output << "Shifting token \"#{name}\" #{loc}\n"
        @debug_output << "   $1 = token \"#{name}\" #{loc}\n"
      end
    end

    # Whether the source has an `__END__`.
    def end_seen?
      !result.data_loc.nil?
    end

    # The source's encoding, as the magic comment decides it.
    def encoding
      result.encoding
    end

    attr_accessor :yydebug
    attr_accessor :debug_output

    # The C core's default handlers answer their FIRST argument (ripper/core.rb's
    # _dispatch_1(a) a ...), which is what a subclass that overrides only a
    # few events sees for the rest: an identifier's token, a list carried
    # through. The translation's answer nil. Every event is aliased again
    # here, because an alias keeps the body it was made with.
    private

    def _dispatch_0() nil end
    def _dispatch_1(a) a end
    def _dispatch_2(a, b) a end
    def _dispatch_3(a, b, c) a end
    def _dispatch_4(a, b, c, d) a end
    def _dispatch_5(a, b, c, d, e) a end
    def _dispatch_6(a, b, c, d, e, f) a end
    def _dispatch_7(a, b, c, d, e, f, g) a end

    PARSER_EVENT_TABLE.each do |id, arity|
      alias_method "on_#{id}", "_dispatch_#{arity}"
    end

    SCANNER_EVENTS.each do |id|
      alias_method "on_#{id}", :_dispatch_1
    end

    public

    # parse.y's dedent_string: strip up to +width+ columns of leading
    # whitespace from +string+ in place (a tab reaches the next multiple of
    # 8 and stays if it would reach past the width); the number of bytes
    # removed.
    def self.dedent_string(string, width)
      col = 0
      i = 0
      len = string.bytesize
      while i < len && col < width
        c = string.getbyte(i)
        if c == 32
          col += 1
        elsif c == 9
          n = 8 * (col / 8 + 1)
          break if n > width
          col = n
        else
          break
        end
        i += 1
      end
      string.replace(string.byteslice(i, len - i)) if i > 0
      i
    end

    # Tokenizes the Ruby program and returns an array of strings.
    def self.tokenize(src, filename = "-", lineno = 1, **kw)
      Lexer.new(src, filename, lineno).tokenize(**kw)
    end

    # Tokenizes the Ruby program and returns an array of an array, which is
    # formatted like `[[lineno, column], type, token, state]`.
    def self.lex(src, filename = "-", lineno = 1, **kw)
      Lexer.new(src, filename, lineno).lex(**kw)
    end

    # The translation's Lexer carries State (the same class LexCompat's
    # tokens hold); ripper/lexer.rb's Elem and the three readers go on it,
    # over the tokens Prism.lex_compat makes.
    class Lexer
      class Elem
        attr_accessor :pos, :event, :tok, :state, :message

        def initialize(pos, event, tok, state, message = nil)
          @pos = pos
          @event = event
          @tok = tok
          @state = State.new(state)
          @message = message
        end

        def [](index)
          case index
          when 0, :pos
            @pos
          when 1, :event
            @event
          when 2, :tok
            @tok
          when 3, :state
            @state
          when 4, :message
            @message
          else
            nil
          end
        end

        def inspect
          "#<#{self.class}: #{event}@#{pos[0]}:#{pos[1]}:#{state}: #{tok.inspect}#{": " if message}#{message}>"
        end

        alias to_s inspect

        def pretty_print(q)
          q.group(2, "#<#{self.class}:", ">") {
            q.breakable
            q.text("#{event}@#{pos[0]}:#{pos[1]}")
            q.breakable
            state.pretty_print(q)
            q.breakable
            q.text("token: ")
            tok.pretty_print(q)
            if message
              q.breakable
              q.text("message: ")
              q.text(message)
            end
          }
        end

        def to_a
          if @message
            [@pos, @event, @tok, @state, @message]
          else
            [@pos, @event, @tok, @state]
          end
        end
      end

      attr_reader :errors

      # Whether the last parse (scan / lex / tokenize) found a syntax error.
      def error?
        !@errors.empty?
      end

      def initialize(src, filename = "-", lineno = 1)
        @source = src.respond_to?(:read) ? src.read : (src.respond_to?(:gets) ? src.gets(nil) : src)
        @filename = filename
        @lineno = lineno
        @errors = []
      end

      attr_reader :filename

      def tokenize(**kw)
        parse(**kw).sort_by(&:pos).map(&:tok)
      end

      def lex(**kw)
        parse(**kw).sort_by(&:pos).map(&:to_a)
      end

      def scan(**kw)
        result = (parse(**kw) + errors).uniq.sort_by { |e| [*e.pos, (e.message ? -1 : 0)] }
        result.each_with_index do |e, i|
          if e.event == :on_parse_error and e.tok.empty? and (pre = result[i - 1]) and
             pre.pos[0] == e.pos[0] and (pre.pos[1] + pre.tok.size) == e.pos[1]
            e.tok = pre.tok
            e.pos[1] = pre.pos[1]
            result[i - 1] = e
            result[i] = pre
          end
        end
        result
      end

      # The tokens, as Prism's Ripper-compatible lexer makes them; a syntax
      # error is an on_parse_error element with the message, as the C core's
      # on_error reports it.
      #
      # Prism.lex_compat leaves out the whitespace between tokens, which
      # parse.y's scanner reports as on_sp (and a `\`-newline continuation
      # likewise), so that Ripper.tokenize(src).join is src again; those are
      # put back here from the source, each with the state of the token
      # before it, as the scanner's are.
      def parse(raise_errors: false)
        source = @source.to_s
        result = Prism.lex_compat(source, filepath: @filename, line: @lineno, version: "current")
        @errors = result.errors.map do |error|
          loc = error.location
          Elem.new([loc.start_line, loc.start_column], :on_parse_error, "", 0, error.message)
        end
        if raise_errors and !@errors.empty?
          raise SyntaxError, @errors.map(&:message).join(" ;")
        end
        lines = source.lines
        offsets = [0]
        lines.each { |l| offsets << offsets.last + l.bytesize }
        # (the tokens in SOURCE order: a heredoc's body is reported after
        #  the line that opens it, and the gaps are between neighbours)
        tokens = result.value.map do |(pos, event, tok, st)|
          line = pos[0] - @lineno
          start = line < offsets.length ? offsets[line] + pos[1] : nil
          [start, pos, event, tok, st.to_int]
        end
        tokens.sort_by! { |t| [t[0] || 0, t[1]] }
        elems = []
        cursor = 0
        state = 0
        prev_state = 0
        tokens.each do |(start, pos, event, tok, st)|
          if start && start > cursor
            gap = source.byteslice(cursor, start - cursor)
            if gap.match?(/\A(?:[ \t\f\r\v]|\\[ \t\n])+\z/)
              at = cursor
              gap.scan(/[ \t\f\r\v]+|\\[ \t\n]/).each do |sp|
                line = offsets.rindex { |o| o <= at }
                elems << Elem.new([line + @lineno, at - offsets[line]], :on_sp, sp, state)
                at += sp.bytesize
              end
            end
          end
          # (the __END__ token is the marker line alone; what follows is
          #  the program's DATA, no token)
          tok = tok[/\A__END__\n?/] if event == :on___end__
          # (an unterminated heredoc has no end token: `EOS ` is not it)
          next if event == :on_heredoc_end && tok.empty?
          elems << Elem.new(pos, event, tok, st)
          cursor = start + tok.bytesize if start && start + tok.bytesize > cursor
          prev_state = state
          state = st
        end
        # (whitespace after the last token -- or a source that is nothing
        #  else -- is on_sp too: `1\n\t \t`, test_lexer's spaces_at_eof; after
        #  a final newline the scanner reports the state the line ended in)
        state = prev_state if elems.last && elems.last.event == :on_nl
        if cursor < source.bytesize
          gap = source.byteslice(cursor, source.bytesize - cursor)
          if gap.match?(/\A(?:[ \t\f\r\v]|\\[ \t\n])+\z/)
            at = cursor
            gap.scan(/[ \t\f\r\v]+|\\[ \t\n]/).each do |sp|
              line = offsets.rindex { |o| o <= at }
              elems << Elem.new([line + @lineno, at - offsets[line]], :on_sp, sp, state)
              at += sp.bytesize
            end
          end
        end
        elems
      end
    end

    def self.slice(src, pattern, n = 0)
      if m = token_match(src, pattern)
      then m.string(n)
      else nil
      end
    end

    def self.token_match(src, pattern) # :nodoc:
      TokenPattern.compile(pattern).match(src)
    end

    class TokenPattern # :nodoc:
      class Error < ::StandardError # :nodoc:
      end
      class CompileError < Error # :nodoc:
      end
      class MatchError < Error # :nodoc:
      end

      class << self
        alias compile new
      end

      def initialize(pattern)
        @source = pattern
        @re = compile(pattern)
      end

      def match(str)
        match_list(Prism::Translation::Ripper.lex(str))
      end

      def match_list(tokens)
        if m = @re.match(map_tokens(tokens))
        then MatchData.new(tokens, m)
        else nil
        end
      end

      private

      def compile(pattern)
        if m = /[^\w\s$()\[\]{}?*+\.]/.match(pattern)
          raise CompileError, "invalid char in pattern: #{m[0].inspect}"
        end
        buf = +""
        pattern.scan(/(?:\w+|\$\(|[()\[\]\{\}?*+\.]+)/) do |tok|
          case tok
          when /\w/
            buf.concat map_token(tok)
          when "$("
            buf.concat "("
          when "("
            buf.concat "(?:"
          when /[?*\[\])\.]/
            buf.concat tok
          else
            raise "must not happen"
          end
        end
        Regexp.compile(buf)
      rescue RegexpError => err
        raise CompileError, err.message
      end

      def map_tokens(tokens)
        tokens.map { |pos, type, str| map_token(type.to_s.delete_prefix("on_")) }.join
      end

      MAP = {}
      seed = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      SCANNER_EVENT_TABLE.each do |ev, |
        raise CompileError, "[RIPPER FATAL] too many system token" if seed.empty?
        MAP[ev.to_s.delete_prefix("on_")] = seed.shift
      end

      def map_token(tok)
        MAP[tok] or raise CompileError, "unknown token: #{tok}"
      end

      class MatchData # :nodoc:
        def initialize(tokens, match)
          @tokens = tokens
          @match = match
        end

        def string(n = 0)
          return nil unless @match
          match(n).join
        end

        private

        def match(n = 0)
          return [] unless @match
          @tokens[@match.begin(n)...@match.end(n)].map { |pos, type, str| str }
        end
      end
    end

    # ripper/filter.rb: an event filter over the lexer's tokens.
    class Filter
      def initialize(src, filename = "-", lineno = 1)
        @__lexer = Lexer.new(src, filename, lineno)
        @__line = nil
        @__col = nil
        @__state = nil
      end

      def filename
        @__lexer.filename
      end

      def lineno
        @__line
      end

      def column
        @__col
      end

      def state
        @__state
      end

      def parse(init = nil)
        data = init
        @__lexer.lex.each do |pos, event, tok, state|
          @__line, @__col = *pos
          @__state = state
          data = if respond_to?(event, true)
                 then __send__(event, tok, data)
                 else on_default(event, tok, data)
                 end
        end
        data
      end

      private

      def on_default(event, token, data)
        data
      end
    end
  end

  Ripper = Prism::Translation::Ripper
end
