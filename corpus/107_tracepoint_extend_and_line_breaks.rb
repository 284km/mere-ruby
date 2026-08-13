# An index may be written across lines, and so may a parameter default.
s = "abc"
p s[
  /b/, 0
]
x = [1, 2, 3]
p x[
  1
]
K = 5
def spread(a, b =
    K,
    c = "")
  [a, b, c]
end
p spread(1)
p spread(1, 2, "z")

# A Regexp answers for its own methods (optparse asks before accepting one).
p [/x/.respond_to?(:match), /x/.respond_to?(:match?), /x/.respond_to?(:source)]

# ...and so does an instance of a builtin's subclass, for the methods the
# subclass defines.
class MyHash < Hash
  def match(k)
    "m:#{k}"
  end
end
h = MyHash.new
p [h.respond_to?(:match), h.match(1), h.respond_to?(:keys), h.class]

# extend works on a mutable primitive (ARGV.extend is how optparse installs
# itself), and the object then is_a? the module.
module Greet
  def hi
    :hi
  end
end
a = [1]
a.extend(Greet)
p [a.hi, a.class, a.size, a.is_a?(Greet), a.singleton_class.ancestors.include?(Greet)]
str = +"s"
str.extend(Greet)
p [str.hi, str.class, str.upcase]

# A superclass that names no constant is a NameError, not a class with a
# dangling parent.
begin
  class Dangling < ::Nope::Thing
  end
rescue NameError => e
  puts "#{e.class}: #{e.message}"
end
begin
  class AlsoDangling < Missing
  end
rescue NameError => e
  puts "#{e.class}: #{e.message}"
end

# ObjectSpace::WeakMap exists (activesupport builds one at load time).
m = ObjectSpace::WeakMap.new
k = "key"
m[k] = 1
p [m[k], m.size, m.key?(k), m.keys]

# Every Encoding constant ruby defines is there, and an alias is the same
# object.
p [Encoding::GB18030.name, Encoding::CP932.name, Encoding::BIG5.equal?(Encoding::Big5)]

# TracePoint(:class) fires when a class or module body is entered.
seen = []
tp = TracePoint.new(:class) do |event|
  seen << event.self.name unless event.self.singleton_class?
end
p tp.enabled?
tp.enable
p tp.enabled?
class Alpha; end
module Beta; end
class Gamma < Alpha
  class Nested; end
end
tp.disable
class AfterDisable; end
p [tp.enabled?, seen]

# `method` reaches a private method, and a builtin operator.
class Priv
  private def hidden(x)
    "h#{x}"
  end
end
def run(&b)
  b.call(7)
end
p run(&Priv.new.method(:hidden))
p "ab".method(:+).call("c")
p 3.method(:+).call(4)
p [1, 2].map(&2.method(:*))

# File.split
p [File.split("/a/b/c.rb"), File.split("x.rb")]
