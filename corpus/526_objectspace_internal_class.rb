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

# Inherited methods and removed methods still leave an existing singleton.
extended = Module.new
extension = Module.new { def marker; :ok; end }
extended.extend(extension)
extended_class = ObjectSpace.internal_class_of(extended)
p [extended.marker, extended_class.equal?(extended.singleton_class)]
removed = Module.new
def removed.marker; :ok; end
removed.method(:marker).owner.send(:remove_method, :marker)
removed_class = ObjectSpace.internal_class_of(removed)
p removed_class.equal?(removed.singleton_class)
empty_extended = Module.new
empty_extended.extend(Module.new)
ec = ObjectSpace.internal_class_of(empty_extended)
p ec.equal?(empty_extended.singleton_class)

# An overridden extend_object that does nothing creates no singleton.
untouched = Module.new
no_extension = Module.new
def no_extension.extend_object(_target); end
untouched.extend(no_extension)
p ObjectSpace.internal_class_of(untouched).equal?(Module)

empty_singleton = Module.new
empty_singleton.singleton_class
[empty_singleton, removed].each do |original|
  [original.dup, original.clone].each do |copy|
    cc = ObjectSpace.internal_class_of(copy)
    p cc.equal?(copy.singleton_class)
  end
end

# A class inside a singleton namespace is still an ordinary class.
holder = Object.new
class << holder
  class Nested; end
end
nested = holder.singleton_class.const_get(:Nested)
nested_class = ObjectSpace.internal_class_of(nested)
p nested_class.equal?(nested.singleton_class)
p nested.singleton_class?

# Class-of chains must reach an existing cycle without growing new classes.
# The exact topology of builtin/internal classes is runtime-specific.
targets = values + [obj, a, m, mc, k, kc, kcc, extended, removed, empty_extended,
                    untouched, nested, nested_class, Class, Module, Object, BasicObject]
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
