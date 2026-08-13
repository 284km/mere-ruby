# A define_method body is a closure over the scope it was written in, and the
# class body it sits in may itself be inside a method.
outer = 7
K = Class.new do
  define_method(:seen) { outer }
end
p K.new.seen

def make(n)
  Class.new do
    define_method(:n) { n }
    define_method(:double) { n * 2 }
  end
end
p [make(3).new.n, make(4).new.double]

# ...and writing through the closure reaches the captured variable, which a
# copy of the values could not do.
counter = 0
class D; end
D.send(:define_method, :bump) { counter += 1 }
p [D.new.bump, D.new.bump, counter]

# the method's own locals stay its own, and self / ivars / class variables /
# super still work from a body defined this way
x = "outer"
class Base
  def greet(n)
    "base #{n}"
  end
end
class Sub < Base
  @@cv = 9
  define_method(:greet) do |n|
    @seen = n
    y = n * 2
    "sub #{n} #{@@cv} #{y}"
  end

  def seen
    @seen
  end
end
s = Sub.new
p s.greet(1)
p s.seen
p x

class WithBlock
  define_method(:each2) { |&b| [1, 2].each { |v| b.call(v) } }
end
acc = []
WithBlock.new.each2 { |v| acc << v }
p acc

# Marshal.dump writes the same subset Marshal.load reads, byte for byte.
[nil, true, false, 0, 1, 122, 123, 255, 256, 70_000, -1, -123, -124, -70_000,
 :sym, "utf8", "".b, 1.5, 0.1, 100.0, 123_000.0, 105.0, 3.0e-5, -0.0,
 [1, [2, :a], "s"], { a: 1, "k" => [2] }, [], {}].each do |v|
  p Marshal.dump(v).bytes
end
p Marshal.dump([:a, :a, :b, :a]).bytes
p Marshal.dump({ x: "s", y: :x }).bytes

deep = { "name" => "utf8 ok", :list => [1, -2, 3.5, nil, true, false],
         :nested => { a: [:x, :x], b: "".b } }
p Marshal.load(Marshal.dump(deep)) == deep
p Marshal.dump(deep).encoding

# Negating a zero keeps its sign: 0.0 - 0.0 is +0.0, so negation cannot be
# written that way.
z = -0.0
p z
p z.to_s
p 1 / z
p [-0.0, 0.0 * -1, -(0.0)]
