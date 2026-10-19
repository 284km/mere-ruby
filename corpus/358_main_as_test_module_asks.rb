# The top-level object as test_module asks (note 382): main has a singleton
# class of its own -- `def self.m`, `class << self`, define_singleton_method
# and `extend M` all write there; singleton_methods and Method#owner see it;
# its private helpers (include, public, private) refuse a receiver other than
# a literal self, and with self they act on Object; and `include Mod` at the
# top level resolves a constant that holds an anonymous module.
def self.foo = 1
p foo
p singleton_class.inspect.start_with?("#<Class:#<Object:0x")
module M382
  def hi = :hi
end
extend M382
p hi
p singleton_class.include?(M382)
p singleton_class.ancestors.first(2).map(&:to_s).last
define_singleton_method(:bar) { 2 }
p bar
class << self
  def baz = 3
end
p baz
p singleton_methods.sort
p method(:foo).owner == singleton_class
p Object.new.respond_to?(:foo)
p self.respond_to?(:foo)
main = self
begin
  main.include(Comparable)
rescue NoMethodError => e
  p e.message
end
begin
  main.public
rescue NoMethodError => e
  p e.message
end
def top382 = :top
self.private :top382
p Object.new.respond_to?(:top382)
send(:public, :top382)
p Object.new.top382
p self.public
Mod382 = Module.new { def from_anon = :anon }
include Mod382
p from_anon
p Object.include?(Mod382)
p TOPLEVEL_BINDING.eval("self").singleton_methods.include?(:baz)
# ...and the warning about a bare `private` inside a method is for the
# method's own body, not for a block written in it
require "stringio"
class C382
  def self.direct; private; end
  def self.in_block; [1].each { private }; end
end
err, $stderr = $stderr, StringIO.new
C382.direct
C382.in_block
Module.new { public }
got, $stderr = $stderr.string, err
p got.lines.size
p got.include?("calling private without arguments inside a method")
# main's singleton outranks Object, for puts too, and puts is a method that
# may stand as an argument
def who = :object
def self.who = :main
p who
p Object.new.send(:who)
p puts("as an argument")
class << self
  def puts(*a) = :mine
end
p puts(1)
