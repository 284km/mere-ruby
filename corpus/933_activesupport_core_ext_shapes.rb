# Shapes from ActiveSupport's own tests that stopped a whole file here.

def try
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

# 1. a block written at `fork` captures the enclosing method's block
#    (ActiveSupport::Testing::Isolation#run_in_isolation yields from it)
def isolated
  IO.pipe do |r, w|
    pid = fork do
      r.close
      w.write(yield.to_s)
      w.close
      exit!(0)
    end
    w.close
    Process.wait(pid)
    r.read
  end
end
p isolated { 6 * 7 }

# 2. Object#respond_to_missing? through super, on values too
#    (array_inquirer_test / string_inquirer_test redefine it on Array and String)
class Array
  def respond_to_missing?(name, include_private = false) = super
end
class String
  def respond_to_missing?(name, include_private = false) = name == :shout || super
end
p [].respond_to?(:foo), [].respond_to?(:size), "x".respond_to?(:shout), "x".respond_to?(:nope)

# 3. questions that stop at their answer on an endless integer range
#    (ActiveSupport's many? is `any? { (cnt += 1) > 1 }`)
inf = 0..Float::INFINITY
p inf.any? { |x| x > 2 }, (0..).any? { |x| x > 2 }, inf.find { |x| x * x > 50 }
p (5..).detect { |x| (x % 7).zero? }, (3..).find_index { |x| x > 10 }
p (0..).all? { |x| x < 5 }, (0..).none? { |x| x > 3 }
p (1..4).any? { |x| x > 9 }, (1..4).all?(&:positive?), (1..4).find { |x| x > 9 }
p (0..).any? { |x| break :out if x == 3 }
module Enumerable
  def many_of?
    cnt = 0
    block_given? ? any? { |*a| cnt += 1 if yield(*a); cnt > 1 } : any? { (cnt += 1) > 1 }
  end
end
p inf.many_of?, inf.many_of? { |x| x > 100 }

# 4. super from a String / Hash subclass into the builtin
#    (ActiveSupport::SafeBuffer's gsub! / sub! / *, HashWithIndifferentAccess#default)
class Buf < String
  def gsub!(*args, &block)
    @unsafe = true
    block ? super(*args) { |*m| block.call(*m) } : super
  end
  def sub!(*args) = super
  def *(n) = self.class.new(super)
  def unsafe? = !!@unsafe
end
b = Buf.new("aXa")
p try { b.gsub!("a", "b") }, b, b.unsafe?
c = Buf.new("aa")
p try { c.gsub!("a") { "c" } }, c
d = Buf.new("hi")
p try { d.sub!("h", "H") }, try { (d * 2).class }, try { d * 2 }

class Indifferent < Hash
  def default(*args) = super(*args.map(&:to_s))
end
h = Indifferent.new { |hash, key| "#{key}!" }
p try { h.default(:ab) }, try { h.default }, h[:x]
plain = Indifferent.new(0)
p plain.default(:anything), plain.default

# 5. a Ruby include? / cover? on Range wins, and its super reaches Range's
#    (ActiveSupport's CompareWithRange is prepended to Range)
module RangeCompare
  def ===(value) = value.is_a?(::Range) ? cover?(value) : super
  def include?(value) = value.is_a?(::Range) ? cover?(value) : super
end
Range.prepend(RangeCompare)
p (1..5).include?(1..5), (1...5).include?(1...5), (1..).include?(2..), (1.0...5.0).include?(1.0...3.0)
p (1..5).include?(3), (1..5).include?(9), (1..5) === (2..3), (1..5) === 3, ("a".."e").include?("c")

# 6. Kernel#=== asked by name of a plain object (minitest's assert_operator)
class Plain; end
o = Plain.new
p o.__send__(:===, o), o.send(:===, 1), o.public_send(:===, o)
class Eqish
  def ==(other) = other == :same
end
p Eqish.new.__send__(:===, :same), Eqish.new.__send__(:===, :other)
