module Psych
  class Emitter < Handler
    attr_reader :indentation, :line_width
    attr_accessor :canonical

    def initialize(io, options = Handler::OPTIONS)
      @io = io
      self.indentation = options.indentation
      self.line_width = options.line_width
      @canonical = options.canonical
      @builder = TreeBuilder.new
      @state = :new
    end

    def indentation=(value)
      n = __integer(value)
      @indentation = (2..9).include?(n) ? n : 2
      value
    end

    def line_width=(value)
      @line_width = __integer(value)
      value
    end

    def start_stream(encoding)
      encoding = __integer(encoding)
      raise RuntimeError, 'expected STREAM-START' unless @state == :new
      raise RuntimeError, 'invalid encoding' unless (0..3).include?(encoding)
      @encoding = encoding
      __write("\uFEFF") if encoding == 2 || encoding == 3
      @builder.start_stream(encoding)
      @state = :stream
      self
    end

    def end_stream
      raise RuntimeError, 'expected DOCUMENT-END' unless @state == :stream
      @builder.end_stream
      @state = :done
      self
    end

    def start_document(version, tags, implicit)
      raise TypeError, 'version must be an Array' unless version.is_a?(Array)
      version = version.map { |v| __integer(v) }
      raise TypeError, 'tags must be an Array' unless tags.is_a?(Array)
      # Conversion can mutate the original array; iterate a stable snapshot.
      tags = tags.dup.map do |pair|
        raise TypeError, 'tag must be an Array' unless pair.is_a?(Array)
        raise RuntimeError, 'tag tuple must be of length 2' unless pair.length == 2
        pair.map { |v| __string(v) }
      end
      raise RuntimeError, 'expected STREAM-START' unless @state == :stream
      @builder.start_document(version, tags, implicit)
      @state = :document
      self
    end

    def end_document(implicit)
      raise RuntimeError, 'expected DOCUMENT-START' unless @state == :document
      doc = @builder.end_document(implicit)
      __write(__document(doc))
      @builder.root.children.clear
      @state = :stream
      self
    end

    def scalar(value, anchor, tag, plain, quoted, style)
      value = __string(value)
      anchor = __anchor(anchor) unless anchor.nil?
      tag = __string(tag) unless tag.nil?
      style = __integer(style)
      @builder.scalar(value, anchor, tag, plain, quoted, style)
      self
    end

    def alias(anchor)
      @builder.alias(__anchor(anchor, 'alias value'))
      self
    end

    def start_sequence(anchor, tag, implicit, style)
      anchor = __anchor(anchor) unless anchor.nil?
      tag = __string(tag) unless tag.nil?
      @builder.start_sequence(anchor, tag, implicit, __integer(style))
      self
    end

    def end_sequence
      @builder.end_sequence
      self
    end

    def start_mapping(anchor, tag, implicit, style)
      anchor = __anchor(anchor) unless anchor.nil?
      tag = __string(tag) unless tag.nil?
      @builder.start_mapping(anchor, tag, implicit, __integer(style))
      self
    end

    def end_mapping
      @builder.end_mapping
      self
    end

    private

    def __integer(value)
      value = value.to_int if value.respond_to?(:to_int)
      raise TypeError, 'no implicit conversion into Integer' unless value.is_a?(Integer)
      raise RangeError, 'integer too big to convert to int' if value < -2147483648 || value > 2147483647
      value
    end

    def __string(value)
      value = value.to_str if !value.is_a?(String) && value.respond_to?(:to_str)
      raise TypeError, 'no implicit conversion into String' unless value.is_a?(String)
      value.encoding == Encoding::UTF_8 ? value : value.encode('UTF-8')
    end

    def __anchor(value, kind = 'anchor value')
      value = __string(value)
      raise RuntimeError, "#{kind} must contain alphanumerical characters only" unless value =~ /\A[0-9A-Za-z_-]+\z/
      value
    end

    def __write(text)
      case @encoding
      when 2 then text = text.encode('UTF-16LE')
      when 3 then text = text.encode('UTF-16BE')
      end
      # Psych's writer labels its buffers UTF-8, including UTF-16 wire bytes.
      @io.write(text.force_encoding('UTF-8'))
    end

    def __properties(node)
      text = +''
      text << "&#{node.anchor} " if node.respond_to?(:anchor) && node.anchor
      if node.tag && (@canonical || (node.respond_to?(:implicit) ? !node.implicit : !(node.plain || node.quoted)))
        tag = node.tag
        tag = if tag.start_with?('tag:yaml.org,2002:')
          '!!' + tag.delete_prefix('tag:yaml.org,2002:')
        elsif tag.start_with?('!')
          tag
        else
          "!<#{tag}>"
        end
        text << tag << ' '
      end
      text
    end

    def __block?(node)
      (node.sequence? || node.mapping?) && node.style != 2 && !node.children.empty? && !@canonical
    end

    def __quote(value)
      escapes = {0 => '\\0', 7 => '\\a', 8 => '\\b', 9 => '\\t', 10 => '\\n', 11 => '\\v', 12 => '\\f', 13 => '\\r', 27 => '\\e', 34 => '\\"', 92 => '\\\\', 133 => '\\N', 160 => '\\_', 8232 => '\\L', 8233 => '\\P'}
      body = value.gsub(/[\x00-\x1f"\\\x7f\u0085\u00a0\u2028\u2029]/) do |character|
        c = character.ord
        escapes[c] || ('\\x%02X' % c)
      end
      '"' + body + '"'
    end

    def __scalar(node, indent, flow)
      value = node.value
      style = node.style
      style = 3 if @canonical
      style = 3 if value =~ /[ \t]\n/
      style = 3 if style <= 3 && value =~ /\n[ \t]/
      style = 3 if value =~ /[\x00-\x08\x0b-\x1f\x7f\u0085\u00a0\u2028\u2029]/
      if style == 4 || style == 5
        style = 3 if flow
      end
      if style == 4 || style == 5
        trailing = value[/\n*\z/].length
        indicator = style == 4 ? '|' : '>'
        indicator += @indentation.to_s if value.start_with?(' ', "\n", "\t")
        keep = trailing > 1 || (trailing > 0 && value.bytesize == trailing)
        indicator += trailing == 0 ? '-' : (keep ? '+' : '')
        value = __folded(value, indent) if style == 5
        body = value.split("\n", -1)
        body.pop if value.end_with?("\n")
        text = body.map { |line| (line.empty? ? '' : (' ' * (indent + @indentation)) + line) + "\n" }.join
        return indicator + "\n" + text
      end
      if style == 3
        return __quote(value)
      end
      return '' if value.empty? && node.plain && style <= 1 && !flow
      unsafe = value.empty? || value.include?("\n") || value =~ /\A[\s\[\]{},&*!|>'"%@`]/ || value =~ /\A[-?:](?:\s|\z)/ || value.include?(': ') || value.include?(' #') || value.end_with?(':', ' ') || (flow && value =~ /[:,\[\]{}]/)
      if style == 2 || unsafe || (!node.plain && !node.tag)
        quoted = value.gsub("'", "''").gsub(/\n+/) { |breaks| "\n" + breaks + (' ' * (indent + @indentation)) }
        return "'" + quoted + "'"
      end
      value
    end

    def __folded(value, indent)
      lines = value.split("\n", -1)
      out = []
      n = 0
      while n < lines.length
        line = lines[n]
        if line.empty?
          out << "\n" if n + 1 < lines.length
          n += 1
          next
        end
        rows = [line]
        if @line_width > 0 && !line.start_with?(' ')
          rows = [+'' ]
          line.split(' ').each do |word|
            if !rows.last.empty? && rows.last.length + indent + @indentation > @line_width
              rows << word.dup
            else
              rows.last << ' ' unless rows.last.empty?
              rows.last << word
            end
          end
        end
        out << rows.join("\n")
        following = n + 1
        following += 1 while following < lines.length && lines[following].empty?
        count = following < lines.length ? following - n : lines.length - n - 1
        if following < lines.length && !line.start_with?(' ') && !lines[following].start_with?(' ')
          count += 1
        end
        out << "\n" * count
        n = following
      end
      out.join
    end

    def __content(node, indent, flow = false)
      return '*' + node.anchor if node.alias?
      properties = __properties(node)
      if node.scalar?
        content = __scalar(node, indent, flow)
        if properties.empty? && node.plain && !node.quoted && (content.start_with?("'", '"', '|', '>'))
          properties = '! '
        end
        return properties + content
      end
      if !__block?(node) || flow
        if @canonical
          pad = ' ' * indent
          child_pad = pad + (' ' * @indentation)
          if node.sequence?
            return properties + "[\n" + node.children.map { |v| child_pad + __content(v, indent + @indentation, true) + ",\n" }.join + pad + ']'
          end
          pairs = node.children.each_slice(2).map do |key, value|
            child_pad + '? ' + __content(key, indent + @indentation, true) + "\n" + child_pad + ': ' + __content(value, indent + @indentation, true) + ",\n"
          end
          return properties + "{\n" + pairs.join + pad + '}'
        end
        if node.sequence?
          return properties + '[' + node.children.map { |v| __content(v, indent, true) }.join(', ') + ']'
        end
        pairs = node.children.each_slice(2).map do |key, value|
          __content(key, indent, true) + ': ' + __content(value, indent, true)
        end
        return properties + '{' + pairs.join(', ') + '}'
      end
      if node.sequence?
        text = node.children.map do |child|
          if __block?(child)
            inner = __content(child, indent + @indentation)
            if __properties(child).empty?
              (' ' * indent) + '-' + (' ' * (@indentation - 1)) + inner[(indent + @indentation)..]
            else
              (' ' * indent) + '- ' + __properties(child).rstrip + "\n" + inner
            end
          else
            content = __content(child, indent)
            (' ' * indent) + (content.empty? ? '-' : '- ' + content) + (content.end_with?("\n") ? '' : "\n")
          end
        end.join
      else
        text = node.children.each_slice(2).map do |key, value|
          prefix = ' ' * indent
          if __block?(key)
            props = __properties(key).rstrip
            if props.empty?
              content = __content(key, indent + @indentation)
              prefix += '? ' + content[(indent + @indentation)..] + (' ' * indent) + ':'
            else
              child_indent = key.sequence? ? indent : indent + @indentation
              prefix += '? ' + props + "\n" + __content(key, child_indent) + (' ' * indent) + ':'
            end
          else
            key_text = __content(key, indent)
            key_text = "! ''" if key_text.empty?
            prefix += key_text + (key.alias? ? ' :' : ':')
          end
          if __block?(value)
            props = __properties(value).rstrip
            child_indent = value.sequence? ? indent : indent + @indentation
            prefix + (props.empty? ? '' : ' ' + props) + "\n" + __content(value, child_indent)
          else
            content = __content(value, indent)
            prefix + (content.empty? ? '' : ' ' + content) + (content.end_with?("\n") ? '' : "\n")
          end
        end.join
      end
      text
    end

    def __document(doc)
      text = +''
      text << "%YAML #{doc.version.join('.')}\n" unless doc.version.empty?
      doc.tag_directives.each { |handle, prefix| text << "%TAG #{handle} #{prefix}\n" }
      root = doc.root
      raise RuntimeError, 'expected a document root' unless root
      properties = __properties(root).rstrip
      marker = !doc.implicit || !text.empty? || @canonical
      if __block?(root)
        text << '---' + (properties.empty? ? '' : ' ' + properties) + "\n" if marker
        text << __content(root, 0)
      else
        content = __content(root, 0)
        text << (content.empty? ? '---' : (@canonical ? "---\n" : '--- ')) if marker
        text << content
        text << "\n" unless content.end_with?("\n")
      end
      text << "...\n" unless doc.implicit_end
      text
    end
  end
end
