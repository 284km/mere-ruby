class Radix952
  def initialize(value) = @value = value
  def to_int = @value
end
class PrivateRadix952
  private
  def to_int = 16
end
class TextRadix952 < String
  def to_int = 16
end
class HashRadix952 < Hash
  def to_int = 16
end
class ClassRadix952
  def self.to_int = 16
end
class MissingRadix952
  def respond_to_missing?(name, priv = false) = name == :to_int || super
  def method_missing(name, *args) = name == :to_int ? 16 : super
end
class Integer
  alias corpus952_native_to_s to_s
end
[123, 2**100].each do |number|
  [{}, nil, false, true, :hex, "16", 16.9, Rational(33, 2),
   Radix952.new(16), PrivateRadix952.new, TextRadix952.new,
   HashRadix952.new, ClassRadix952, MissingRadix952.new,
   Radix952.new(nil), Radix952.new("16"), Radix952.new(16.0),
   Radix952.new(2**32), Radix952.new(2**100), Float::NAN,
   Float::INFINITY, -Float::INFINITY, 1e100].each do |base|
    begin
      p number.to_s(base)
    rescue => error
      p [error.class, error.message]
    end
  end
end
base = Radix952.new(16)
p 123.corpus952_native_to_s(base)
p 123.method(:to_s).call(base)
p Integer.instance_method(:to_s).bind_call(123, base)
