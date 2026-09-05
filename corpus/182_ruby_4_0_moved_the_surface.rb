# The reference ruby moved from 3.4.9 to 4.0.6 (2026-09-05). This is what 4.0
# changed that the other corpus programs did not already ask about; 175 of the
# 180 files before it print the same under both rubies, and the five that do
# not are Set#inspect, `require "set"`, strip's arity and an openssl message.

# a line that begins with `and` / `or` / `&&` / `||` continues the one before
x = 1
  and 2
p x
y = false
  || 3
p y
z = nil
  or :z
p z
w = true
  # a comment line between them is fine
  && false
p w
def keep(v)
  v
end
p keep(1
  && 2)
q = 1 + 2
  || :never
p q

# Set is core: its inspect, its recursion sentinel, and a subclass's own shape
s = Set[3, 1, 2]
p s
p s.to_s
puts s.inspect
p Set[]
p Set[Set[1], [2, [3]]]
r = Set[1]
r << r
p r
p Set[1].freeze
class MySet < Set; end
p MySet[1, 2]
p MySet.new
p require("set")
p((1..3).to_set)
p((1..3).to_set { |v| v * 10 })
a = Set[1]
p a.to_set.equal?(a)
begin
  (1..).to_set
rescue RangeError => e
  p [e.class, e.message]
end

# Pathname is core: the constant and the conversion function need no require
p defined?(Pathname)
p Pathname("/a/b").basename.to_s
p Pathname("/a/b").is_a?(Pathname)

# strip / lstrip / rstrip take selectors, intersected like #count's
p "xxhixx".strip("x"), "xxhixx".lstrip("x"), "xxhixx".rstrip("x")
p "abchicba".strip("a-c"), "xhix".strip("^h"), " hi ".strip(""), "  hi  ".strip("x")
p "abhiba".strip("ab", "a"), "hhih".strip("h", "h")
t = "xxhixx"
p t.strip!("x"), t, "hi".strip!("q")
begin
  " a ".strip(1)
rescue TypeError => e
  p [e.class, e.message]
end
begin
  "a".lstrip(:a)
rescue TypeError => e
  p [e.class, e.message]
end

# new names
p [1, 2, 3, 4].rfind { |v| v.odd? }, [2, 4].rfind { |v| v.odd? }
p Math.log1p(0), Math.expm1(0), Math.log1p(1) == Math.log(2)
p Math.expm1(1000), Math.log1p(-1)
p 1.method(:+).box

# Kernel#inspect asks instance_variables_to_inspect which ivars to show
class Shown
  def initialize; @a = 1; @b = 2; @c = 3; end
  def instance_variables_to_inspect; [:@c, :@a, :@zz]; end
end
puts Shown.new.inspect.sub(/0x[0-9a-f]+/, "0x")
class Hidden
  def initialize; @a = 1; end
  def instance_variables_to_inspect; []; end
end
puts Hidden.new.inspect.sub(/0x[0-9a-f]+/, "0x")
class Plain
  def initialize; @a = 1; end
end
puts Plain.new.inspect.sub(/0x[0-9a-f]+/, "0x")
p Object.new.send(:instance_variables_to_inspect)

# the Ruby module carries the identity constants; boxes are not enabled
p Ruby::VERSION == RUBY_VERSION, Ruby::ENGINE, Ruby::PLATFORM == RUBY_PLATFORM
p Ruby::Box.enabled?
p Ruby.constants.sort

# a destructuring block parameter has no name to report
p proc { |(a, b), c| }.parameters, lambda { |(a, b)| }.parameters
