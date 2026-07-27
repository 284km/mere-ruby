# A small Markdown-to-HTML converter (single file, no deps).
# Handles: ATX headings, fenced code blocks, blockquotes, unordered and
# ordered lists, horizontal rules, paragraphs, and inline spans (code, bold,
# italic, links, autolinks). Written in ordinary Ruby, not tuned to any
# particular interpreter.
module MiniMark
  class Inline
    ENTITIES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;" }.freeze

    def self.escape(text)
      text.gsub(/[&<>]/) { |c| ENTITIES[c] }
    end

    def self.render(text)
      s = escape(text)
      # inline code first so its contents are not further formatted
      s = s.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }
      # links [label](url)
      s = s.gsub(/\[([^\]]+)\]\(([^)]+)\)/) { %(<a href="#{$2}">#{$1}</a>) }
      # autolinks <http://...>
      s = s.gsub(%r{&lt;(https?://[^\s]+?)&gt;}) { %(<a href="#{$1}">#{$1}</a>) }
      # bold then italic
      s = s.gsub(/\*\*([^*]+)\*\*/) { "<strong>#{$1}</strong>" }
      s = s.gsub(/\*([^*]+)\*/) { "<em>#{$1}</em>" }
      s
    end
  end

  class Document
    def initialize(src)
      @lines = src.split("\n")
      @out = []
    end

    def to_html
      i = 0
      while i < @lines.length
        line = @lines[i]
        case line
        when /\A```/
          i = fenced_code(i)
        when /\A\#{1,6}\s+/
          heading(line)
          i += 1
        when /\A\s*(?:-{3,}|\*{3,})\s*\z/
          @out << "<hr>"
          i += 1
        when /\A>\s?/
          i = blockquote(i)
        when /\A\s*[-*+]\s+/
          i = unordered_list(i)
        when /\A\s*\d+\.\s+/
          i = ordered_list(i)
        when /\A\s*\z/
          i += 1
        else
          i = paragraph(i)
        end
      end
      @out.join("\n") + "\n"
    end

    private

    def heading(line)
      line =~ /\A(\#{1,6})\s+(.*?)\s*#*\s*\z/
      level = $1.length
      @out << "<h#{level}>#{Inline.render($2)}</h#{level}>"
    end

    def fenced_code(i)
      lang = @lines[i].sub(/\A```/, "").strip
      body = []
      i += 1
      while i < @lines.length && @lines[i] !~ /\A```/
        body << @lines[i]
        i += 1
      end
      cls = lang.empty? ? "" : %( class="language-#{lang}")
      @out << "<pre><code#{cls}>#{Inline.escape(body.join("\n"))}</code></pre>"
      i + 1
    end

    def blockquote(i)
      body = []
      while i < @lines.length && @lines[i] =~ /\A>\s?/
        body << @lines[i].sub(/\A>\s?/, "")
        i += 1
      end
      inner = Document.new(body.join("\n")).to_html.chomp
      @out << "<blockquote>\n#{inner}\n</blockquote>"
      i
    end

    def unordered_list(i)
      items = []
      while i < @lines.length && @lines[i] =~ /\A\s*[-*+]\s+(.*)/
        items << $1
        i += 1
      end
      @out << "<ul>"
      items.each { |it| @out << "<li>#{Inline.render(it)}</li>" }
      @out << "</ul>"
      i
    end

    def ordered_list(i)
      items = []
      while i < @lines.length && @lines[i] =~ /\A\s*\d+\.\s+(.*)/
        items << $1
        i += 1
      end
      @out << "<ol>"
      items.each { |it| @out << "<li>#{Inline.render(it)}</li>" }
      @out << "</ol>"
      i
    end

    def paragraph(i)
      body = []
      while i < @lines.length && @lines[i] !~ /\A\s*\z/ &&
            @lines[i] !~ /\A(?:```|\#{1,6}\s|>|\s*[-*+]\s|\s*\d+\.\s)/
        body << @lines[i].strip
        i += 1
      end
      @out << "<p>#{Inline.render(body.join(" "))}</p>"
      i
    end
  end

  def self.to_html(src)
    Document.new(src).to_html
  end
end

sample = <<~'MD'
  # MiniMark Demo

  A tiny **Markdown** converter written in *pure* Ruby. It supports `inline
  code`, [links](https://example.com), and <https://ruby-lang.org>.

  ## Features

  - headings & paragraphs
  - **bold** and *italic*
  - lists, both kinds

  1. first
  2. second
  3. third

  > A quote with **emphasis**.
  > Spanning two lines.

  ---

  Here is some code:

  ```ruby
  def greet(name)
    puts "Hello, #{name}!"
  end
  ```

  That's all for now.
MD

puts MiniMark.to_html(sample)
