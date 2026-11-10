# Type-membership caches follow anonymous ancestry mutations.
mixed = Module.new
klass = Class.new
object = klass.new
p object.is_a?(mixed)
klass.include(mixed)
p object.is_a?(mixed)
p object.kind_of?(mixed)

nested = Module.new
p object.is_a?(nested)
mixed.include(nested)
p object.is_a?(nested)

prepended = Module.new
p object.is_a?(prepended)
klass.prepend(prepended)
p object.is_a?(prepended)

stable_object = Object.new
300.times do
  transient_module = Module.new
  transient_class = Class.new
  transient_object = transient_class.new
  raise "wrong miss" if transient_object.is_a?(transient_module)
  raise "wrong named receiver" if stable_object.is_a?(transient_module)
  transient_class.include(transient_module)
  raise "stale membership" unless transient_object.is_a?(transient_module)
end
3.times { GC.start }
p [object.is_a?(mixed), object.is_a?(nested), object.is_a?(prepended)]
