# Two places where a class-like object did not print as ruby prints it.
#
# 1. Array#join asks every element its #to_s, a class too. minitest's spec
#    classes answer the name they were described with -- #to_s and #name come
#    from a module the base class extends -- and a nested `describe` builds
#    its name with `[stack.last, desc].join("::")`. The join wrote the class
#    as `#<Class:0x...>`, so 77 of Arel's tests ran under names ruby does not
#    give them.
module DSL
  def name = defined?(@name) ? @name : super
  def to_s = name
  def create(n) = Class.new(self) { @name = n }
end
class Spec; extend DSL; end
c = Spec.create("Outer::the thing")
p c.to_s, "#{c}"
p [c, "nested"].join("::")
p [nil, c, "y"].compact.join("::")
p [[c, 1], :s].join("-")
# a plain class and module, and an anonymous one
class Plain; end
p [Plain, Comparable, 1].join(","), [String].join.encoding
p [Class.new].join.sub(/0x\h+/, "0x")
# its own singleton #to_s
class Own; def self.to_s = "own!"; end
p [Own, Own].join(" ")

# 2. An instance of a Module subclass is a module: the constant it is
#    assigned to names it, and it prints by that name. ActiveRecord's
#    GeneratedAttributeMethods is `Class.new(Module)`-like, set with
#    const_set on each model, and `Post.ancestors.reject(&:name)` has to be
#    empty.
class GM < Module; end
class Top; end
g = GM.new
p g.name, g.inspect.sub(/0x\h+/, "0x"), g.to_s.sub(/0x\h+/, "0x")
Top.const_set(:Gen, g)
p g.name, g, g.inspect, g.to_s, "#{g}", [g]
p Top::Gen.equal?(g), Top.constants.include?(:Gen)
k = GM.new
K = k
p k, k.name
# by assignment under a class
j = GM.new
Top::J = j
p j, j.name
# a subclass's own #inspect is still its own
class GI < Module; def inspect = "custom"; end
i = GI.new
Top::I = i
p i, i.to_s, i.name
# the first name stays
Other = g
p g, g.name
# in ancestors
class User; end
User.include(g)
p User.ancestors.first(2), User.ancestors.reject(&:name)
