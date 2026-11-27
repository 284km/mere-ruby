# `defined?(name)` with a class as self asks the CLASS whether it has the
# method: its singleton methods, and its own #respond_to_missing? if it has
# one. The #respond_to_missing? its INSTANCES have is not the class's.
#
# ActiveRecord::TestFixtures defines #respond_to_missing? (calling super) for
# the test instances, and its class method `fixtures` reads
#
#   names.reject! { ... } if defined?(file_fixture_path) && file_fixture_path
#
# The instances' method was called on the class, and its `super` found
# nothing: "undefined method 'respond_to_missing?' for class #<Class:0x...>".
module TF
  def self.included(b) = b.extend(CM)
  module CM
    def fx = defined?(zork) ? :defined : :not_defined
    def fy = [1].flat_map { |x| defined?(zork) && zork; [x] }
    def fz = defined?(zork(1))
  end
  def respond_to_missing?(m, p = false) = super
  def method_missing(m, *a) = super
  def inst = defined?(zork)
end
k = Class.new { include TF }
p k.fx, k.fy, k.fz
class Named; include TF; end
p Named.fx, Named.respond_to?(:zork), k.respond_to?(:zork)
p k.new.inst, k.new.respond_to?(:zork)

# a class that DOES claim names for itself is believed
class Claims
  def self.respond_to_missing?(m, p = false) = m == :zork || super
  def self.fx = [defined?(zork), defined?(other)]
  def respond_to_missing?(m, p = false) = m == :inst_only || super
  def fi = [defined?(inst_only), defined?(zork)]
end
p Claims.fx, Claims.new.fi
# ...and one whose instances claim a name does not claim it itself
class OnlyInst
  def respond_to_missing?(m, p = false) = true
  def self.fx = defined?(anything)
  def fi = defined?(anything)
end
p OnlyInst.fx, OnlyInst.new.fi
# a module as self
module Mod
  def self.respond_to_missing?(m, p = false) = m == :mm
  def self.fx = [defined?(mm), defined?(nn)]
end
p Mod.fx
