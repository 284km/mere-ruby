# What the reflection lists name: Object's, BasicObject's and Comparable's
# public methods in #methods and #instance_methods, Kernel's functions kept
# private, aliases of the methods every object has (as openstruct makes them,
# with a `!`), and coerce on what is not a number.

def try407
  yield
rescue StandardError => e
  [e.class, e.message]
end

class Plain407
  def mine = :mine
  private def hidden = :hidden
end

p Object.instance_methods.size, Object.new.methods.size, Object.new.public_methods.size
p Plain407.instance_methods.include?(:mine), Plain407.instance_methods.include?(:hidden)
p Plain407.instance_methods.include?(:class), Plain407.instance_methods(false)
p (Object.instance_methods - Kernel.instance_methods).sort
p BasicObject.instance_methods.sort, Comparable.instance_methods.sort
p Kernel.instance_methods.size, Kernel.instance_methods.include?(:=~)
p Object.instance_methods.include?(:require), Object.private_instance_methods.include?(:require)
p try407 { Object.new.require("set") }.first

class Undef407
  undef_method :tap
  private :inspect
end
p Undef407.instance_methods.include?(:tap), Undef407.instance_methods.include?(:inspect)
p Undef407.new.methods.include?(:tap), Undef407.private_instance_methods.include?(:inspect)

# openstruct's way: an alias with a `!` of every public method
class Bang407
  instance_methods.each do |m|
    next if m.match(/\W$/)
    alias_method :"#{m}!", m
  end
  alias_method :raise!, :raise
  private :raise!
  alias_method :block_given!, :block_given?
  private :block_given!
  alias_method :not!, :!
  def r1 = (raise! ArgumentError, "one", caller(1) rescue $!)
  def r2 = (raise!(TypeError, "two") rescue $!)
  def b1 = block_given!
  def b2(&) = block_given!()
end
o = Bang407.new
p o.class!, o.r1.class, o.r1.message, o.r2, o.b1, o.b2 {}, o.not!
p o.instance_eval! { self.class }, o.instance_exec!(2) { |x| x * 2 }, o.hash! == o.hash, o.dup!.class

p try407 { nil.coerce(1) }, try407 { "x".coerce(1) }, try407 { :s.coerce(1) }
p 1.coerce(2.5), 1.5.coerce(2)
