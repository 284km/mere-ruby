# Interpolation parts negotiate their encodings without synthetic empty pieces.
values = ['"#{3}"', '"#{3}#{4}"', '"#{3}" ""', '"" "#{3}"', '"#{3}" "#{4}"', '"#{3}#{\'\'}"', '"#{\'\'}#{3}"', '"#{nil}"', '"#{true}"', '"#{false}"', '"#{:foo}"', '"#{3}\n"']
values.each do |src|
  value = eval(src)
  p [src, value.bytes, value.encoding.name]
end
%w[UTF-8 US-ASCII ASCII-8BIT EUC-JP UTF-16LE].each do |encoding|
  ['', 'abc'].each do |text|
    x = text.encode(encoding)
    ['"#{x}"', '"#{x}#{1}"', '"#{1}#{x}"', '"a#{x}"', '"#{x}a"'].each do |src|
      begin
        value = eval(src)
        p [encoding, text, src, value.bytes, value.encoding.name]
      rescue Encoding::CompatibilityError => error
        p [encoding, text, src, error.class]
      end
    end
  end
end

x=3;y=4
['"" "#{x}#{y}"', '"#{x}#{y}" ""', '"a" "#{x}#{y}"', '"#{x}#{y}" "a"', '"#{x}" "#{y}"', '"#{x}" "#{y}#{x}"', '"#{x}#{y}" "#{x}"', '"#{x}#{y}" "#{x}#{y}"'].each do |src|
 value=eval(src);p [src,value,value.encoding.name]
end

# to_s is evaluated once, left to right, and strings bypass an override.
class InterpolationPiece
  def initialize(text, label, calls)
    @text, @label, @calls = text, label, calls
  end
  def to_s
    @calls << @label
    GC.start
    @text
  end
end
calls = []
a = InterpolationPiece.new('a'.encode('US-ASCII'), :a, calls)
b = InterpolationPiece.new('b'.encode('EUC-JP'), :b, calls)
s = "#{a}#{b}"
p [s.bytes, s.encoding.name, calls]
class InterpolationString < String
  def to_s; raise 'string interpolation called to_s'; end
end
x = InterpolationString.new('x').force_encoding('US-ASCII')
y = InterpolationString.new('y').force_encoding('EUC-JP')
s = "#{x}#{y}"
p [s, s.class, s.encoding.name, s.equal?(x), s.equal?(y)]

# Quotes and commands use the same interpolation semantics; capture the command.
def `(command); command; end
x = 1
p ["#{x}#{''}".encoding.name, `#{x}#{''}`.encoding.name]
p ["#{x}#{x}".encoding.name, "#{x}#{x}".to_sym.encoding.name]

# Source encoding belongs to literal parts, not to the final dynamic result.
%w[UTF-8 US-ASCII ASCII-8BIT EUC-JP Windows-31J].each do |coding|
  x = 'x'.encode('US-ASCII')
  y = 'y'.encode('EUC-JP')
  ['"#{x}"', '"#{x}#{y}"', '"#{x}#{y}" "#{x}"', '"a#{x}#{y}"',
   '"#{x}#{y}a"', '"#{x}#{""}#{y}"'].each do |source|
    [false, true].each do |frozen|
      header = "# coding: " + coding + "\n# frozen_string_literal: " + frozen.to_s + "\n"
      value = eval((header + source).encode(coding))
      p [coding, frozen, value.bytes, value.encoding.name, value.frozen?]
    end
  end
end

# Adjacent interpolated literals do not invoke a replaced String#+.
class String
  def +(other); raise 'literal concatenation called String#+'; end
end
x = 3
s = "#{x}#{x}" "#{x}"
p [s.bytes, s.encoding.name]
