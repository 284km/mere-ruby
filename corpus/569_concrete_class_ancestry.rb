# Class membership follows superclasses; mixins keep their full ancestry.
base = Class.new
child = Class.new(base)
leaf = Class.new(child)
mixin = Module.new
nested = Module.new
mixin.include(nested)
child.include(mixin)
front = Module.new
leaf.prepend(front)
object = leaf.new
targets = [base, child, leaf, mixin, nested, front, Object, BasicObject, Class, Module, String]
p targets.map { |target| object.is_a?(target) }
def object.local_method; :local; end
p targets.map { |target| object.kind_of?(target) }
3.times { GC.start }
p targets.map { |target| object.is_a?(target) }

values = [Object.new, [], {}, "value", 7, 1.5, RuntimeError.new("message"), (1..2).lazy]
core_targets = [Object, BasicObject, Array, Hash, String, Integer, Numeric, Float,
                Exception, StandardError, Class, Module, Enumerable, Comparable, Enumerator]
values.each { |value| p core_targets.map { |target| value.is_a?(target) } }
[Array, Hash, String, Time, StandardError].each do |parent|
  subtype = Class.new(parent)
  value = subtype.new
  p [value.is_a?(subtype), value.is_a?(parent), value.is_a?(Object), value.is_a?(Module)]
end
