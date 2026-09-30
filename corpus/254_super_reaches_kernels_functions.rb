# Kernel's functions are ancestors of every object, so `super` from an
# override of one reaches it. ruby/spec's CodeLoadingSpecs::Method is
# `def load(name, wrap = false) = super`; wrapping puts is the ordinary case.
require "tmpdir"
class Loud
  def puts(*a) = super(*a.map { |x| x.to_s.upcase })
  def print(*a) = super("[", *a, "]\n")
  def p(*a) = super
  def format(f, *a) = "<" + super + ">"
  def Integer(x) = super(x) * 2
  def rand(*a) = super.class
  def load(name, wrap = false) = super
  def raise_it = raise(ArgumentError, "kept")
end
l = Loud.new
l.puts "quiet", :sym
l.print 1, 2
p l.p(:x)
p l.format("%05.1f", 3.14159)
p l.Integer("21")
p l.rand(10)
p((l.raise_it rescue $!.message))
Dir.mktmpdir do |d|
  f = File.join(d, "loaded.rb")
  File.write(f, "puts :loaded_by_super\n$loaded = true\n")
  p l.load(f)
  p $loaded
end

# a module included into a class sits between it and Kernel
module Tagging
  def puts(*a) = super("tag:", *a)
end
class Tagged
  include Tagging
  def run = puts("hello")
end
Tagged.new.run

# and the override itself still wins for a plain call
class Own
  def puts(x) = "own #{x}"
  def go = puts(1)
end
p Own.new.go

# puts is a call like any other, so it may stand where a value can
def shout = puts("from an endless def")
shout
r = (puts "in parens")
p r
p(true && puts("after &&"))

# print ends with $\, the output record separator (ruby -l sets it to $/)
$VERBOSE = nil
$\ = "|\n"
print "a", "b"
$stdout.print "c"
$\ = nil
print "done\n"
