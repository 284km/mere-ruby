# Comparison has two layers here: a value-level comparator, and a world-aware one
# that can call a user-defined <=>. Only `sort`, `min` and `max` were registered
# in the second, so everything else fell through to the first and could not reach
# an object's own <=>. The failure also LEAKED an interpreter-internal message
# ("comparison of incompatible types") instead of ruby's ArgumentError, which is
# what hid all of this: the message named neither side.
class V
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(other); n <=> other.n; end
end
arr = [V.new(2), V.new(1), V.new(3)]
p arr.sort.map(&:n)
p arr.dup.sort!.map(&:n)
p arr.minmax.map(&:n)
p [arr.min.n, arr.max.n]
p({ V.new(2) => :b, V.new(1) => :a }.sort.map { |k, v| [k.n, v] })
p([V.new(1)] <=> [V.new(2)])
p([V.new(2)] <=> [V.new(1), V.new(9)])

class Bag
  include Enumerable
  def initialize(*v); @v = v; end
  def each(&b); @v.each(&b); end
end
bag = Bag.new(V.new(2), V.new(1))
p bag.sort.map(&:n)
p bag.minmax.map(&:n)

# ruby's own message, naming both sides
begin
  [1, "a"].sort
rescue ArgumentError => e
  p e.message
end

# `module_function` copies a method to the module's singleton -- and has to take
# the lexical scope with it, or the copy resolves constants from the top level
# and cannot see its own module's. bundler's GemHelpers is written that way.
module Namespace
  module Helpers
    def uses_own_constant
      OWN
    end
    module_function :uses_own_constant

    def self.defined_directly
      OWN
    end

    OWN = :found
  end
end
p [Namespace::Helpers.uses_own_constant, Namespace::Helpers.defined_directly]
