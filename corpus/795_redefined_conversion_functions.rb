# A bare Float() / Integer() is a call of whatever Kernel, Object or self
# defines under the name, as `send(:Float, ...)` is -- not the builtin
# whatever the program defined. And a builtin that calls a builtin function
# serializes, but ruby will not load it back.

p [Float("1.5"), Integer("12"), String(3), Array(nil)]

module Kernel
  undef Float
  def Float(n) = [:kernel_float, n]
end
p Float(30)
p send(:Float, 31)

class Object
  def Integer(n) = [:object_integer, n]
end
p Integer(7)

class ConvOwn
  def String(x) = [:own_string, x]
  def check = String(1)
end
p ConvOwn.new.check
p [String(2), Array([3])]

r = Ractor.new do
  module Kernel
    def Rational(*a) = :ractor_rational
  end
  Rational(1, 2)
end
p r.value

bin = RubyVM::InstructionSequence.of(1.method(:abs)).to_binary
begin
  RubyVM::InstructionSequence.load_from_binary(bin)
  p :loaded
rescue ArgumentError => e
  p [:refused, e.message]
end
plain = RubyVM::InstructionSequence.compile("1 + 2").to_binary
p RubyVM::InstructionSequence.load_from_binary(plain).eval
