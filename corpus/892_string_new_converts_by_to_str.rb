# String.new(obj) converts obj by #to_str, as rb_str_init's StringValue does:
# it was a TypeError for any object that is not already a String
class Src
  def initialize(s) = @s = s
  def to_str = @s
end
class Bad; def to_str = 1; end
s = String.new(Src.new("ab"))
p [s, s.class, s.encoding]
p String.new(Src.new("é".encode("ISO-8859-1"))).encoding
p String.new(Src.new("x"), encoding: "ASCII-8BIT").encoding
p String.new(Src.new("cap"), capacity: 100)
[Bad.new, 1, nil, :sym, Object.new].each do |v|
  begin
    String.new(v)
  rescue TypeError => e
    p e.message
  end
end
