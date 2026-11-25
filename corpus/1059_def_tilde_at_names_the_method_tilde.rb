# `def ~@` and `def ~` define the same method, named :~ (as `def !@` and
# `def !` are both :!). Arel's Math writes `def ~@` for BitwiseNot.

module Bits
  def ~@
    [:not, self.class]
  end
end

Attr = Struct.new(:relation, :name) { include Bits }
p(~ Attr.new(:products, :bitmap))
p(~Attr.new(:products, :bitmap))

class Flags
  include Bits
end
f = Flags.new
p ~f
p f.send(:~)
p f.public_send(:~)
p f.method(:~).arity
p Flags.instance_method(:~).owner
p Bits.instance_methods.sort
p f.respond_to?(:~)

# the bare spelling, with and without parentheses
class Plain
  def ~
    :plain
  end
end
p(~Plain.new)

class Parens
  def ~@()
    :parens
  end
end
p(~Parens.new)

# a body on the same line
class OneLine; def ~@; :one_line; end; end
p(~OneLine.new)

# a singleton method
o = Object.new
def o.~@
  :singleton
end
p(~o)
p o.singleton_methods

# the other unary operators as singleton methods
s = Object.new
def s.-@; :neg; end
def s.+@; :pos; end
def s.!@; :bang; end
p [-s, +s, !s]
p s.singleton_methods.sort

# a class method: `~K` calls it like any other receiver's ~
class K
  def self.~@
    :class_tilde
  end
end
p(~K)

# a receiver with no ~ is NoMethodError, as any call is
p((~"str" rescue $!.class), (~nil rescue $!.class), (~Object.new rescue $!.class))

# a subclass of a Struct subclass, as Arel::Attribute is
class Sub < Attr; end
p(~Sub.new(:t, :c))

# beside the other unary operators
class Unary
  def -@ = :neg
  def +@ = :pos
  def !@ = :bang
  def ~@ = :tilde
end
u = Unary.new
p [-u, +u, !u, ~u]
p Unary.instance_methods(false).sort

# Integer's own ~ is untouched
p [~5, ~0, ~-1]
