# `super` from a class's own `dup` (or `clone`) reaches Module#dup and answers
# a COPY: a new class with the original's methods, mixins and superclass. It
# answered the class itself.
#
# ActiveRecord::Inheritance::ClassMethods defines
#
#   def dup
#     other = super
#     other.set_base_class
#     other
#   end
#
# and the tests build throwaway models with `NumericData.dup`. With the class
# itself for a copy, a validation added to the "copy" was added to
# NumericData and to every later copy: 8 tests of
# numericality_validation_test failed on validations another test had added.
k = Class.new { def self.dup = super; def im = 1 }
d = k.dup
p d.equal?(k), d.class, d.new.im, d.superclass

module ClassMethods
  def dup
    other = super
    other.instance_variable_set(:@copied, true)
    other
  end
  def clone(**kw)
    other = super
    other.instance_variable_set(:@cloned, true)
    other
  end
  def copied? = [@copied, @cloned]
end
class Base
  extend ClassMethods
  def self.cm = :cm
  def im = :im
  X = 1
end
class Model < Base; def mm = :mm; end
d = Model.dup
p d.equal?(Model), d.name, d.superclass, d.copied?, Model.copied?
p d.new.mm, d.new.im, d.cm, d.new.class.equal?(d), d.new.is_a?(Model), d.new.is_a?(Base)
# what is defined on the copy is the copy's
d.define_singleton_method(:only_on_copy) { 1 }
d.class_eval { def added = 1 }
p Model.respond_to?(:only_on_copy), Model.method_defined?(:added), d.method_defined?(:added)
# two copies are two classes
e = Model.dup
p e.equal?(d), e.method_defined?(:added), e.copied?
c = Model.clone
p c.equal?(Model), c.copied?, c.new.mm
c = Model.clone(freeze: false)
p c.equal?(Model), c.frozen?
# a named copy
Named = Model.dup
p Named.name, Named.new.mm, Named.equal?(Model)
# a module
module M0; def self.dup = super; def mi = 1; end
m = M0.dup
p m.equal?(M0), m.class, m.instance_methods
# a class with no #dup of its own is as it was
class Plain; def pi = 1; end
q = Plain.dup
p q.equal?(Plain), q.new.pi, q.name
# a class's copy has its class methods, by #dup and by #clone alike (a
# class's singleton class is copied with it)...
class WithS
  def self.dup = super
  def self.clone(**kw) = super
  def self.s = :s
end
p WithS.dup.s, WithS.clone.s
p (WithS.dup.singleton_methods - [:dup, :clone]), (WithS.clone.singleton_methods - [:dup, :clone])
p WithS.dup.singleton_class.equal?(WithS.singleton_class)
# ...where an ordinary object's #dup leaves its singleton methods behind
o = Object.new
def o.s = 1
p o.clone.respond_to?(:s), o.dup.respond_to?(:s)
# frozen or not: #clone keeps it unless told otherwise, #dup never does
f = WithS.clone(freeze: true)
p f.frozen?, f.equal?(WithS), WithS.frozen?
fz = Class.new { def self.dup = super; def self.clone(**kw) = super }
fz.freeze
p fz.dup.frozen?, fz.clone.frozen?, fz.clone(freeze: false).frozen?, fz.clone(freeze: true).frozen?
