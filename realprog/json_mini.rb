# A pure-Ruby JSON library: a recursive-descent parser and a generator with
# optional pretty-printing. Written in ordinary Ruby. Used to round-trip a
# nested/wide structure and check that generate -> parse -> generate is
# idempotent, which leans on deep recursion and a lot of allocation.

module JSONMini
  class ParseError < StandardError; end

  class Parser
    ESCAPES = {
      '"' => '"', "\\" => "\\", "/" => "/", "b" => "\b",
      "f" => "\f", "n" => "\n", "r" => "\r", "t" => "\t"
    }.freeze

    def initialize(src)
      @src = src
      @pos = 0
      @len = src.length
    end

    def parse
      skip_ws
      value = parse_value
      skip_ws
      raise ParseError, "trailing garbage at #{@pos}" if @pos < @len
      value
    end

    private

    def skip_ws
      @pos += 1 while @pos < @len && " \t\n\r".include?(@src[@pos])
    end

    def peek
      @src[@pos]
    end

    def parse_value
      case peek
      when "{" then parse_object
      when "[" then parse_array
      when '"' then parse_string
      when "t", "f" then parse_bool
      when "n" then parse_null
      else parse_number
      end
    end

    def expect(ch)
      raise ParseError, "expected #{ch.inspect} at #{@pos}, got #{peek.inspect}" unless peek == ch
      @pos += 1
    end

    def parse_object
      expect("{")
      obj = {}
      skip_ws
      if peek == "}"
        @pos += 1
        return obj
      end
      loop do
        skip_ws
        key = parse_string
        skip_ws
        expect(":")
        skip_ws
        obj[key] = parse_value
        skip_ws
        case peek
        when ","
          @pos += 1
        when "}"
          @pos += 1
          break
        else
          raise ParseError, "expected ',' or '}' at #{@pos}"
        end
      end
      obj
    end

    def parse_array
      expect("[")
      arr = []
      skip_ws
      if peek == "]"
        @pos += 1
        return arr
      end
      loop do
        skip_ws
        arr << parse_value
        skip_ws
        case peek
        when ","
          @pos += 1
        when "]"
          @pos += 1
          break
        else
          raise ParseError, "expected ',' or ']' at #{@pos}"
        end
      end
      arr
    end

    def parse_string
      expect('"')
      out = +""
      until peek == '"'
        raise ParseError, "unterminated string" if @pos >= @len
        ch = @src[@pos]
        if ch == "\\"
          @pos += 1
          esc = @src[@pos]
          if esc == "u"
            hex = @src[(@pos + 1)...(@pos + 5)]
            out << [hex.to_i(16)].pack("U")
            @pos += 5
          else
            out << (ESCAPES[esc] || raise(ParseError, "bad escape \\#{esc}"))
            @pos += 1
          end
        else
          out << ch
          @pos += 1
        end
      end
      @pos += 1
      out
    end

    def parse_number
      start = @pos
      @pos += 1 if peek == "-"
      @pos += 1 while @pos < @len && ("0".."9").include?(@src[@pos])
      is_float = false
      if peek == "."
        is_float = true
        @pos += 1
        @pos += 1 while @pos < @len && ("0".."9").include?(@src[@pos])
      end
      if peek == "e" || peek == "E"
        is_float = true
        @pos += 1
        @pos += 1 if peek == "+" || peek == "-"
        @pos += 1 while @pos < @len && ("0".."9").include?(@src[@pos])
      end
      text = @src[start...@pos]
      raise ParseError, "bad number at #{start}" if text.empty? || text == "-"
      is_float ? text.to_f : text.to_i
    end

    def parse_bool
      if @src[@pos, 4] == "true"
        @pos += 4
        true
      elsif @src[@pos, 5] == "false"
        @pos += 5
        false
      else
        raise ParseError, "bad literal at #{@pos}"
      end
    end

    def parse_null
      raise ParseError, "bad literal at #{@pos}" unless @src[@pos, 4] == "null"
      @pos += 4
      nil
    end
  end

  class Generator
    def initialize(pretty: false)
      @pretty = pretty
    end

    def generate(value)
      emit(value, 0)
    end

    private

    def emit(value, depth)
      case value
      when Hash then emit_object(value, depth)
      when Array then emit_array(value, depth)
      when String then quote(value)
      when Integer then value.to_s
      when Float then value.to_s
      when true then "true"
      when false then "false"
      when nil then "null"
      else raise "cannot serialize #{value.class}"
      end
    end

    def nl(depth)
      @pretty ? "\n" + ("  " * depth) : ""
    end

    def emit_object(hash, depth)
      return "{}" if hash.empty?
      inner = hash.map do |k, v|
        "#{nl(depth + 1)}#{quote(k.to_s)}:#{@pretty ? " " : ""}#{emit(v, depth + 1)}"
      end
      "{#{inner.join(",")}#{nl(depth)}}"
    end

    def emit_array(arr, depth)
      return "[]" if arr.empty?
      inner = arr.map { |v| "#{nl(depth + 1)}#{emit(v, depth + 1)}" }
      "[#{inner.join(",")}#{nl(depth)}]"
    end

    def quote(str)
      out = +'"'
      str.each_char do |ch|
        out << case ch
               when '"' then '\\"'
               when "\\" then "\\\\"
               when "\n" then "\\n"
               when "\t" then "\\t"
               when "\r" then "\\r"
               else ch
               end
      end
      out << '"'
      out
    end
  end

  def self.parse(src)
    Parser.new(src).parse
  end

  def self.generate(value, pretty: false)
    Generator.new(pretty: pretty).generate(value)
  end
end

# Build a deterministic, moderately deep + wide structure without any RNG.
def build(depth, width)
  return depth if depth <= 0
  node = {
    "depth" => depth,
    "label" => "node-#{depth}",
    "flags" => [true, false, nil],
    "ratio" => depth.to_f / 3,
    "kids"  => (1..width).map { |i| build(depth - 1, [width - 1, 0].max) if i == 1 }.compact,
    "leaves" => (0...width).map { |i| "leaf-#{depth}-#{i}" }
  }
  node
end

# A linear-recursion chain to exercise stack depth specifically.
def chain(n)
  return { "end" => true } if n <= 0
  { "n" => n, "next" => chain(n - 1) }
end

def checksum(value)
  case value
  when Hash  then value.reduce(7) { |acc, (k, v)| (acc * 31 + k.length + checksum(v)) % 1_000_000_007 }
  when Array then value.reduce(3) { |acc, v| (acc * 17 + checksum(v)) % 1_000_000_007 }
  when String then value.length
  when Integer then value % 1000
  when Float then value.to_i % 1000
  when true then 1
  when false then 0
  when nil then 2
  end
end

data = {
  "tree"  => build(6, 5),
  "chain" => chain(40),
  "meta"  => { "version" => 1, "note" => "round-trip test", "empty" => {}, "list" => [] }
}

gen1   = JSONMini.generate(data, pretty: true)
parsed = JSONMini.parse(gen1)
gen2   = JSONMini.generate(parsed, pretty: true)

puts "idempotent: #{gen1 == gen2}"
puts "checksum:   #{checksum(parsed)}"
puts "bytes:      #{gen1.bytesize}"
puts "chain-depth reparsed: #{parsed["chain"].size rescue "n/a"}"
puts gen1.lines.first(12).join
