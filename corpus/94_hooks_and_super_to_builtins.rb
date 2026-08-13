# `extended` fires like `included`, and `super` from a method defined in a
# module reaches the built-in it overrides (Class#new, Module#autoload).
module Hooked
  def self.extended(base)
    base.class_eval do
      @table = Hash.new { |h, k| h[k] = [] }
    end
  end
  def push(k, v); @table[k] << v; self; end
  def table; @table; end
end
module Registry
  extend Hooked
end
Registry.push(:a, 1).push(:a, 2)
p Registry.table

module SafeInit
  def new(*args, &block)
    r = super(*args, &block)
    $built = ($built || 0) + 1
    r
  end
end
class Widget
  extend SafeInit
  def initialize(v = nil); @v = v; end
  def v; @v; end
end
p Widget.new(7).v
p $built

module PathAutoload
  def autoload(const_name, path = nil)
    super const_name, (path || "corpus/lib/#{const_name.to_s.downcase}")
  end
end
module Lazy
  extend PathAutoload
  autoload :Thing
end
p Lazy.autoload?(:Thing)

# a `raise:` keyword parameter shadows the raise keyword
def opts(key, throw: false, raise: false)
  (throw && :throw || raise && :raise) || :none
end
p opts(1)
p opts(1, raise: true)
p opts(1, throw: true)

# a block-pass stays last even when keyword arguments precede it
def inner(*a, k: nil, &b); [a, k, b ? b.call : nil]; end
def outer(*a, k: nil, &b); inner(*a, k: k, &b); end
p outer(1, 2, k: :x)
p outer(1) { :from_block }

# Symbol answers the String-like queries; the case ones answer with a Symbol
p :DEBUG.downcase
p :abc.upcase
p [:abc.start_with?("a"), :abc.length, :abc[1]]

# Integer#size is the machine word width
p 0.size
p((2 ** ((0.size * 8) - 2)) - 1)

# a class method aliased to a builtin one
class Node
  def initialize(a, b); @a = a; @b = b; end
  def to_a; [@a, @b]; end
  singleton_class.send :alias_method, :[], :new
end
p Node[1, 2].to_a

# Recv::setter = value is the same call as Recv.setter = value
class Cur
  def self.current; @c; end
  def self.current=(v); @c = v; end
end
Cur::current = 5
p Cur::current
Cur::current = nil
p Cur::current

# a paren-less argument list continues after a newline
class Consts
  A = 1
  B = 2
  private_constant :A,
                   :B
  def a; 1; end
  def b; 2; end
  private :a,
          :b
end
p Consts.new.respond_to?(:a)
p Consts.new.respond_to?(:b)

# a subject-less case on one line, and a constant bound to one
X = case when false then 1 when true then 2 else 3 end
p X
