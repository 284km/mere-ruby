# Integer#fdiv must retain the integer when converting it first overflows.
number = 10**500
[number, -number].each do |value|
  [1e200, -1e200, 1e-200, -1e-200, Float::MAX,
   0.0, -0.0, Float::INFINITY, -Float::INFINITY, Float::NAN].each do |divisor|
    begin
      p [divisor, value.fdiv(divisor)]
    rescue => error
      p [divisor, error.class, error.message]
    end
  end
end
# Ordinary conversions and integer-pair division keep their existing paths.
p (10**100).fdiv(1e20)
p number.fdiv(10**200)
p (number * 3).fdiv(number * 2)
coerced = Object.new
def coerced.coerce(value) = [value, 1e200]
p number.fdiv(coerced)
class Integer
  alias saved_fdiv_1113 fdiv
end
p number.saved_fdiv_1113(1e200)
