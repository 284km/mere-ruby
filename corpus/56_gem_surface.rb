# The pieces that let RubyGems find, activate and load a gem.

require "forwardable"
require "singleton"
require "thread"

# a class can BE an Enumerable: `extend Enumerable` + `def self.each`
class Registry
  extend Enumerable
  ITEMS = [3, 1, 2]
  def self.each(&b); ITEMS.each(&b); end
end
p Registry.count, Registry.to_a, Registry.sort, Registry.include?(2)
p Registry.min, Registry.max, Registry.inject(:+)
p Registry.select { |x| x > 1 }.sort
p Registry.map { |x| x * 2 }.sort
p Registry.find { |x| x == 2 }

# `yield` inside a block reaches the method the block was WRITTEN in, even
# after the block has been handed to another method that has its own
def inner(items)
  items.map { |path| yield path }.select { |x| !x.nil? }
end
def outer(dirs)
  dirs.flat_map do |dir|
    base = dir + "-base"
    inner(["a", "b"]) { |path| yield path, base }
  end
end
p(outer(["d1", "d2"]) { |p1, b| [p1, b] })

# any? / all? / none? without a block, and with a pattern
p [1, nil].all?, [nil].none?, [1, 2].any?, [].any?, [].all?, [].none?
p [1, 2].all?(Integer), [1, 2].none?(String), [1, 2].any?(String)
p({a: 1}.any?, {}.any?)
p((1..3).any?, (1..3).all?)

# `p a, (expr).method` — the parenthesised argument is a value to chain from,
# not a second argument list
p 1.abs, (-2).abs
p 1, (1..3).to_a

# Numeric#nonzero?, String#delete_prefix!/delete_suffix!
p 0.nonzero?, 5.nonzero?, 0.0.nonzero?
p((1 <=> 1).nonzero? || :tie)
a = +"foobar"
p a.delete_prefix!("foo"), a
b = +"foobar"
p b.delete_prefix!("zzz"), b
c = +"foobar"
p c.delete_suffix!("bar"), c

# @ivar reflection on main and on primitive receivers
p instance_variable_get(:@nope), instance_variable_defined?(:@nope)
@here = 1
p instance_variable_get(:@here), instance_variables
s = +"str"
s.instance_variable_set(:@tag, 7)
p s.instance_variable_get(:@tag), s.instance_variables
p 1.instance_variable_defined?(:@x)

# define_singleton_method with a block
class WithSingleton
  define_singleton_method(:computed) { |n| n * 3 }
end
p WithSingleton.computed(2)

# Forwardable / SingleForwardable / Singleton ship as source
class Box
  extend Forwardable
  def initialize(a); @a = a; end
  def_delegator :@a, :size
  def_delegators :@a, :first, :last
  def_delegator :@a, :join, :joined
end
box = Box.new([1, 2, 3])
p box.size, box.first, box.last, box.joined("-")

class Store
  extend SingleForwardable
  @items = [9, 8]
  def self.items; @items; end
  def_delegator :items, :size, :item_count
end
p Store.item_count

class OnlyOne
  include Singleton
  def hi; :hi; end
end
p OnlyOne.instance.hi, OnlyOne.instance.equal?(OnlyOne.instance)

# __FILE__ is the file the expression is written in
p File.basename(__FILE__)
