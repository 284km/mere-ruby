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
            gap = source.byteslice(cursor, start - cursor).b
            if gap.match?(/\A(?:[ \t\f\r\v]|\\[ \t\n])+\z/n)
              at = cursor
              gap.scan(/[ \t\f\r\v]+|\\[ \t\n]/n).each do |sp|
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
          # (a heredoc's end line leaves the state where its body left it:
          #  parse.y scans the body and the end as one string, and Prism
          #  gives the end the state after the whole literal)
          st = state if event == :on_heredoc_end
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
          gap = source.byteslice(cursor, source.bytesize - cursor).b
          if gap.match?(/\A(?:[ \t\f\r\v]|\\[ \t\n])+\z/n)
            at = cursor
            gap.scan(/[ \t\f\r\v]+|\\[ \t\n]/n).each do |sp|
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

  # (reopened nested, so that the node classes the method below names
  #  resolve as they do in the translation's own file)
  module Prism
    module Translation
      class Ripper
        # The translation's #parse (prism 1.9), with parse.y's way of reporting:
        #
        # - a magic comment's name has its "-" as "_" (parser_magic_comment);
        # - a warning goes to #warn when parse.y's is rb_warn and to #warning when
        #   it is rb_warning, with parse.y's format and arguments -- the
        #   translation sent Prism's :default level to #warning and the rest to
        #   #warn, the other way round, and the message as the format;
        # - an ambiguous binary operator is the operator_ambiguous parser event;
        # - an error the lexer finds is #compile_error with parse.y's words
        #   (Prism's add "unterminated heredoc; " or "; expected a closing
        #   delimiter" around them), the rest on_parse_error as before.
        # (under the name #parse above calls, which keeps the parser's
        #  position readers and yydebug around it)
        def __translation_parse
          result.comments.each do |comment|
            location = comment.location
            bounds(location)

            if comment.is_a?(InlineComment)
              on_comment(comment.slice)
            else
              offset = location.start_offset
              lines = comment.slice.lines

              lines.each_with_index do |line, index|
                bounds(location.copy(start_offset: offset))

                if index == 0
                  on_embdoc_beg(line)
                elsif index == lines.size - 1
                  on_embdoc_end(line)
                else
                  on_embdoc(line)
                end

                offset += line.bytesize
              end
            end
          end

          result.magic_comments.each do |magic_comment|
            on_magic_comment(magic_comment.key.tr("-", "_"), magic_comment.value)
          end

          unless result.data_loc.nil?
            on___end__(result.data_loc.slice.each_line.first)
          end

          result.warnings.each do |warning|
            bounds(warning.location)
            __parse_y_warning(warning)
          end

          # (parse.y builds the tree on through the errors below -- a write
          #  it refuses is wrapped in assign_error, an alias of $1 is
          #  alias_error -- so the parse answers it; any other error, and
          #  the parse answers nil as the translation did)
          @__verrs = nil
          if error?
            walk = result.errors.all? { |error| PARSE_Y_WALKS.include?(error.type) }
            @__verrs = {} if walk
            heredoc_id = false
            result.errors.each do |error|
              location = error.location
              bounds(location)

              # (`<<"` with nothing after: Prism ignores the `<<` and finds a
              #  string that does not end; parse.y says the one thing)
              if error.type == :unexpected_token_ignore && location.slice == "<<"
                heredoc_id = true
                on_parse_error("unterminated here document identifier")
              elsif heredoc_id && error.type == :string_literal_eof
                # (the same error, already reported)
              elsif walk && PARSE_Y_AT_NODE.include?(error.type)
                @__verrs[location.start_offset] = error
              elsif walk && error.type == :invalid_retry_without_rescue
                # (a misplaced retry is the compiler's refusal, not the parser's)
              else
                __parse_y_error(error, location)
              end
            end

            walk ? result.value.accept(self) : nil
          else
            result.value.accept(self)
          end
        end

        PARSE_Y_AT_NODE = %i[write_target_readonly expression_not_writable_self write_target_in_method
                             alias_argument_numbered_reference].freeze
        PARSE_Y_WALKS = (PARSE_Y_AT_NODE + %i[invalid_retry_without_rescue def_endless_setter
                                              argument_formal_class argument_formal_constant
                                              argument_formal_global argument_formal_ivar]).freeze
        private_constant :PARSE_Y_AT_NODE, :PARSE_Y_WALKS

        private

        # (one error, dispatched as parse.y reports it)
        def __parse_y_error(error, location)
          case error.type
          when :alias_argument, :alias_argument_numbered_reference
            on_alias_error("can't make alias for the number variables", location.slice)
          when :argument_formal_class
            on_param_error("formal argument cannot be a class variable", location.slice)
          when :argument_format_constant, :argument_formal_constant
            on_param_error("formal argument cannot be a constant", location.slice)
          when :argument_formal_global
            on_param_error("formal argument cannot be a global variable", location.slice)
          when :argument_formal_ivar
            on_param_error("formal argument cannot be an instance variable", location.slice)
          when :class_name, :module_name
            on_class_name_error("class/module name must be CONSTANT", location.slice)
          when :incomplete_variable_instance, :incomplete_variable_class, :instance_variable_bare,
               :class_variable_bare, :invalid_variable_global, :global_variable_bare
            compile_error(error.message)
          when :regexp_term
            compile_error(error.message.delete_suffix("; expected a closing delimiter"))
          when :heredoc_term
            compile_error(error.message.delete_prefix("unterminated heredoc; "))
          when :argument_no_forwarding_star, :argument_no_forwarding_star_star, :argument_no_forwarding_ampersand
            compile_error(error.message.sub(/\Aunexpected `[^`]*`; /, ""))
          else
            on_parse_error(error.message)
          end
        end

        # (a write parse.y refused, at the offset its error was found at)
        def __assign_error(offset, field)
          error = @__verrs && @__verrs.delete(offset)
          error ? on_assign_error(error.message, field) : field
        end

        public

        def visit_global_variable_write_node(node)
          bounds(node.name_loc)
          target = __assign_error(node.name_loc.start_offset, on_var_field(on_gvar(node.name.to_s)))
          value = visit_write_value(node.value)

          bounds(node.location)
          on_assign(target, value)
        end

        def visit_global_variable_operator_write_node(node)
          bounds(node.name_loc)
          target = on_var_field(on_gvar(node.name.to_s))

          bounds(node.binary_operator_loc)
          operator = on_op("#{node.binary_operator}=")
          value = visit_write_value(node.value)

          bounds(node.location)
          __assign_error(node.name_loc.start_offset, on_opassign(target, operator, value))
        end

        # (`$&, _ = 1`: Prism has the back reference as the target)
        def visit_back_reference_read_node(node)
          bounds(node.location)
          error = @__verrs && @__verrs.delete(node.location.start_offset)
          error ? on_assign_error(error.message, on_var_field(on_backref(node.slice))) : on_backref(node.slice)
        end

        def visit_constant_write_node(node)
          bounds(node.name_loc)
          target = __assign_error(node.name_loc.start_offset, on_var_field(on_const(node.name.to_s)))
          value = visit_write_value(node.value)

          bounds(node.location)
          on_assign(target, value)
        end

        def visit_constant_target_node(node)
          bounds(node.location)
          __assign_error(node.location.start_offset, on_var_field(on_const(node.name.to_s)))
        end

        def visit_constant_path_write_node(node)
          target = __assign_error(node.target.location.start_offset, visit_constant_path_write_node_target(node.target))
          value = visit_write_value(node.value)

          bounds(node.location)
          on_assign(target, value)
        end

        def visit_constant_path_target_node(node)
          __assign_error(node.location.start_offset, visit_constant_path_write_node_target(node))
        end

        # (`self = 1`: a write Prism names "self", refused at its `=`)
        def visit_local_variable_write_node(node)
          bounds(node.name_loc)
          target =
            if node.name == :self && @__verrs && (key = @__verrs.keys.find { |o| o >= node.location.start_offset && o < node.location.end_offset })
              on_assign_error(@__verrs.delete(key).message, on_var_field(on_kw("self")))
            else
              on_var_field(on_ident(node.name_loc.slice))
            end
          value = visit_write_value(node.value)

          bounds(node.location)
          on_assign(target, value)
        end

        def visit_alias_global_variable_node(node)
          new_name = visit_alias_global_variable_node_value(node.new_name)
          # (`$1` is a numbered reference, which the translation's reader of
          #  an alias's names did not take: parse.y's token is a backref)
          old_name =
            if node.old_name.is_a?(NumberedReferenceReadNode)
              bounds(node.old_name.location)
              on_backref(node.old_name.slice)
            else
              visit_alias_global_variable_node_value(node.old_name)
            end

          bounds(node.location)
          error = @__verrs && @__verrs.delete(node.old_name.location.start_offset)
          error ? on_alias_error("can't make alias for the number variables", old_name) : on_var_alias(new_name, old_name)
        end

        private

        # (one Prism warning as parse.y gives it: the method, the format and its
        #  arguments, read back out of Prism's words where parse.y passes them)
        def __parse_y_warning(warning)
          message = warning.message
          case warning.type
          when :ambiguous_first_argument_plus
            on_arg_ambiguous("+")
          when :ambiguous_first_argument_minus
            on_arg_ambiguous("-")
          when :ambiguous_slash
            on_arg_ambiguous("/")
          when :ambiguous_binary_operator
            if (m = message.match(/\A'(.+)' after local variable or literal is interpreted as binary operator even though it seems like (.+)\z/))
              on_operator_ambiguous(m[1].to_sym, m[2])
            end
          when :duplicated_hash_key
            if (m = message.match(/\Akey (.+) is duplicated and overwritten on line (\d+)\z/))
              warn("key %s is duplicated and overwritten on line %d", __parse_y_literal(m[1]), m[2].to_i)
            else
              warn(message)
            end
          when :duplicated_when_clause
            if (m = message.match(/\A'when' clause on line (\d+) duplicates 'when' clause on line (\d+) and is ignored\z/))
              warning("'when' clause on line %d duplicates 'when' clause on line %d and is ignored", m[1].to_i, m[2].to_i)
            else
              warning(message)
            end
          when :invalid_magic_comment_value
            if (m = message.match(/\Ainvalid value for (.+): (.*)\z/))
              warning("invalid value for %s: %s", m[1], m[2])
            else
              warning(message)
            end
          when :ignored_frozen_string_literal
            warning("'%s' is ignored after any tokens", "frozen_string_literal")
          when :indentation_mismatch
            if (m = message.match(/\Amismatched indentations at '(.+)' with '(.+)' at (\d+)\z/))
              warn("mismatched indentations at '%s' with '%s' at %d", m[1], m[2], m[3].to_i)
            else
              warn(message)
            end
          else
            warning.level == :default ? warn(message) : warning(message)
          end
        end

        # (a key as Prism writes it -- an inspected Symbol, String or Integer --
        #  back into the value parse.y passes)
        def __parse_y_literal(text)
          case text
          when /\A:(\w+[?!=]?)\z/ then $1.to_sym
          when /\A-?\d+\z/ then text.to_i
          when /\A"(.*)"\z/m then $1
          else text
          end
        end

        public

        # The translation's visit_call_node (prism 1.9, ruby 4.0.9), one line
        # changed. A receiverless call without parentheses is a command when the
        # NODE has arguments; the translation asked the VALUE its args events
        # returned (`arguments&.any?`), and a value is whatever the subclass's
        # handlers answer. test/ripper's parse-files Parser answers Object.new for
        # every event, so every such call raised NoMethodError (55 tests). The C
        # core never looks inside what a handler returns. The receiver branch
        # below already decides by the node; this decides the same way.
        def visit_call_node(node)
          if node.call_operator_loc.nil?
            case node.name
            when :[]
              receiver = visit(node.receiver)
              arguments, block = visit_call_node_arguments(node.arguments, node.block, trailing_comma?(node.arguments&.location || node.location, node.closing_loc))

              bounds(node.location)
              call = on_aref(receiver, arguments)

              if block.nil?
                call
              else
                bounds(node.location)
                on_method_add_block(call, block)
              end
            when :[]=
              receiver = visit(node.receiver)

              *arguments, last_argument = node.arguments.arguments
              arguments << node.block if !node.block.nil?

              arguments =
                if arguments.any?
                  args = visit_arguments(arguments)

                  if !node.block.nil?
                    args
                  else
                    bounds(arguments.first.location)
                    on_args_add_block(args, false)
                  end
                end

              bounds(node.location)
              call = on_aref_field(receiver, arguments)
              value = visit_write_value(last_argument)

              bounds(last_argument.location)
              on_assign(call, value)
            when :-@, :+@, :~
              receiver = visit(node.receiver)

              bounds(node.location)
              on_unary(node.name, receiver)
            when :!
              if node.message == "not"
                receiver =
                  if !node.receiver.is_a?(ParenthesesNode) || !node.receiver.body.nil?
                    visit(node.receiver)
                  end

                bounds(node.location)
                on_unary(:not, receiver)
              else
                receiver = visit(node.receiver)

                bounds(node.location)
                on_unary(:!, receiver)
              end
            when *BINARY_OPERATORS
              receiver = visit(node.receiver)
              value = visit(node.arguments.arguments.first)

              bounds(node.location)
              on_binary(receiver, node.name, value)
            else
              bounds(node.message_loc)
              message = visit_token(node.message, false)

              if node.variable_call?
                on_vcall(message)
              else
                arguments, block = visit_call_node_arguments(node.arguments, node.block, trailing_comma?(node.arguments&.location || node.location, node.closing_loc || node.location))
                call =
                  if node.opening_loc.nil? && (!node.arguments.nil? || node.block.is_a?(BlockArgumentNode))
                    bounds(node.location)
                    on_command(message, arguments)
                  elsif !node.opening_loc.nil?
                    bounds(node.location)
                    on_method_add_arg(on_fcall(message), on_arg_paren(arguments))
                  else
                    bounds(node.location)
                    on_method_add_arg(on_fcall(message), on_args_new)
                  end

                if block.nil?
                  call
                else
                  bounds(node.block.location)
                  on_method_add_block(call, block)
                end
              end
            end
          else
            receiver = visit(node.receiver)

            bounds(node.call_operator_loc)
            call_operator = visit_token(node.call_operator)

            message =
              if node.message_loc.nil?
                :call
              else
                bounds(node.message_loc)
                visit_token(node.message, false)
              end

            if node.name.end_with?("=") && !node.message.end_with?("=") && !node.arguments.nil? && node.block.nil?
              value = visit_write_value(node.arguments.arguments.first)

              bounds(node.location)
              on_assign(on_field(receiver, call_operator, message), value)
            else
              arguments, block = visit_call_node_arguments(node.arguments, node.block, trailing_comma?(node.arguments&.location || node.location, node.closing_loc || node.location))
              call =
                if node.opening_loc.nil?
                  bounds(node.location)

                  if node.arguments.nil? && !node.block.is_a?(BlockArgumentNode)
                    on_call(receiver, call_operator, message)
                  else
                    on_command_call(receiver, call_operator, message, arguments)
                  end
                else
                  bounds(node.opening_loc)
                  arguments = on_arg_paren(arguments)

                  bounds(node.location)
                  on_method_add_arg(on_call(receiver, call_operator, message), arguments)
                end

              if block.nil?
                call
              else
                bounds(node.block.location)
                on_method_add_block(call, block)
              end
            end
          end
        end
      end
    end
  end

  Ripper = Prism::Translation::Ripper
end
