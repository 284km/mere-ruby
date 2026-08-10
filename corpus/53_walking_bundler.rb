# The gaps found by walking bundler's load: each is general Ruby, not
# bundler-specific.

# ?x is a one-character string for ANY character, not just word characters.
p ?a, ?Z, ?1, [?,, ?., ?-, ?/].join
p "a/b/".chomp(?/)
p [?\n.bytes, ?\s, ?\t.bytes]
# ...but a wildcard after a value is still a ternary.
x = 5
p(x > 3 ? "big" : "small")
c = true
p(c ? ?y : ?n)
p %w[a/b c/d].map {|s| s.split(?/) }

# a parameter list may wrap across lines
def cp_lr(src, dest, noop: nil, verbose: nil,
          dereference_root: true, remove_destination: false)
  [src, dest, noop, verbose, dereference_root, remove_destination]
end
p cp_lr(1, 2)
p cp_lr(1, 2, noop: true,
        remove_destination: true)
def wrapped(
  a,
  b = 2,
  *rest,
  key:,
  **opts,
  &blk
)
  [a, b, rest, key, opts, blk.nil?]
end
p wrapped(1, 2, 3, 4, key: 5, z: 6)

# a `when` value list may wrap too
def kind(v)
  case v
  when Integer,
       Float then
    :num
  when String,
       Symbol
    :name
  else
    :other
  end
end
p kind(1), kind(1.0), kind("s"), kind(:s), kind([])

# a constant path anchored at the top level
module Outer
  module Helper
    def helped; :helped; end
  end
  Z = 9
end
class WithHelper
  include ::Outer::Helper
end
class ExtHelper
  extend ::Outer::Helper
end
p WithHelper.new.helped, ExtHelper.helped
p(::Outer::Z)
p(::Outer::Helper.instance_methods(false))
# `a::B` stays scope resolution on `a`, never `a(::B)`
def lower_a; nil; end
p defined?(lower_a::B)

# the head of a qualified constant resolves lexically
module Nest
  class Inner
    K = %w[
      a
      b
    ].map(&:freeze).freeze
  end
  p Inner::K
  p defined?(Inner::K)
end
p Nest::Inner::K

# reopening Object / Kernel adds methods callable with an implicit self
module Kernel
  def doubled(v); v * 2; end
  def Wrapped(v); [v]; end
end
class Object
  def bumped(v); v + 1; end
end
p doubled(3), Wrapped(3), bumped(1)
class UsesThem
  def go; [doubled(2), bumped(2)]; end
end
p UsesThem.new.go

# visibility with a computed name list
class Visibility
  def a; 1; end
  def b; 2; end
  names = [:b]
  private :a
  private(*names)
end
p Visibility.private_instance_methods(false).sort - [:initialize]

# Module#methods: class methods, including inherited ones
class Base
  def self.from_base; end
end
class Derived < Base
  def self.from_derived; end
end
p(Derived.methods.include?(:from_derived), Derived.methods.include?(:from_base))
p(Derived.singleton_methods.sort)

# super() with no user-defined superclass method lands on BasicObject#initialize
module Marker; end
class Plain
  include Marker
  def initialize; super(); @set = true; end
end
p Plain.new.instance_variable_get(:@set)
