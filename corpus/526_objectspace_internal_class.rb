require 'objspace'

# Reading an object's internal class must not create a singleton class or call
# an overridden Ruby method. This includes values that cannot have singletons.
values = [Object.new, BasicObject.new, [], {}, 'mutable'.dup, 'frozen'.freeze,
          -> {}, binding, /rx/, 1..3, 1, 2**100, 1.5, :symbol, nil, true, false,
          Rational(1, 2), Complex(1, 2)]
expected = [Object, BasicObject, Array, Hash, String, String, Proc, Binding,
            Regexp, Range, Integer, Integer, Float, Symbol, NilClass, TrueClass,
            FalseClass, Rational, Complex]
p values.zip(expected).all? { |value, klass| ObjectSpace.internal_class_of(value).equal?(klass) }

class InternalClassArray < Array; end
a = InternalClassArray.new
p ObjectSpace.internal_class_of(a).equal?(InternalClassArray)
[Object.new, [], {}, 's'.dup, -> {}, binding, /singleton/.dup, a].each do |o|
  sc = o.singleton_class
  p ObjectSpace.internal_class_of(o).equal?(sc)
end

obj = Object.new
def obj.class; raise 'must not call class'; end
def obj.singleton_class; raise 'must not open a singleton'; end
p ObjectSpace.internal_class_of(obj).singleton_class?

# A module acquires an internal singleton only when it actually needs one.
m = Module.new
p ObjectSpace.internal_class_of(m).equal?(Module)
def m.answer; 42; end
mc = ObjectSpace.internal_class_of(m)
p mc.equal?(m.singleton_class)

k = Class.new
kc = ObjectSpace.internal_class_of(k)
p kc.equal?(k.singleton_class)
kcc = ObjectSpace.internal_class_of(kc)
p kcc.equal?(kc.singleton_class)
class << k
  def answer; 41; end
end
p [k.answer, m.answer]

# Class-of chains must reach an existing cycle without growing new classes.
# The exact topology of builtin/internal classes is runtime-specific.
targets = values + [obj, a, m, mc, k, kc, kcc, Class, Module, Object, BasicObject]
count = ObjectSpace.each_object(Class).count
bounded = targets.all? do |value|
  seen = {}.compare_by_identity
  32.times do
    break if seen.key?(value)
    seen[value] = true
    value = ObjectSpace.internal_class_of(value)
  end
  seen.key?(value)
end
p bounded
p ObjectSpace.each_object(Class).count == count
GC.start
p ObjectSpace.internal_class_of(a).equal?(a.singleton_class)
