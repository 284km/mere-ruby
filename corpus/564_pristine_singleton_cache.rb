# Shared lookup keys must stop applying when a singleton becomes observable
# or gains methods, aliases, tombstones or mixed-in ancestors.
def check(value)
  raise 'singleton cache lost a mutation' unless value
end
parent = Class.new
children = [Class.new(parent), Class.new(parent)]
children.each { |child| 3.times { check(!child.respond_to?(:probe)) } }
parent.define_singleton_method(:probe) { 10 }
children.each { |child| check(child.probe == 10) }
parent.singleton_class.send(:remove_method, :probe)
children.each { |child| check(!child.respond_to?(:probe)) }
parent.define_singleton_method(:probe) { 11 }
children[0].singleton_class.send(:undef_method, :probe)
check(!children[0].respond_to?(:probe))
check(children[1].probe == 11)
children[0].define_singleton_method(:probe) { 12 }
check(children[0].probe == 12)
check(children[1].probe == 11)

fresh = Class.new(parent)
3.times { check(!fresh.respond_to?(:mixed)) }
mixin = Module.new { def mixed; 20; end }
fresh.extend(mixin)
check(fresh.mixed == 20)
mixin.module_eval { def mixed; 21; end }
check(fresh.mixed == 21)
check(!Class.new(parent).respond_to?(:mixed))

aliased = Module.new
other = Module.new
3.times { check(!other.respond_to?(:cached_name)) }
aliased.singleton_class.send(:alias_method, :cached_name, :name)
check(aliased.cached_name.nil?)
check(!other.respond_to?(:cached_name))
check(!Module.new.respond_to?(:cached_name))

hooks = []
3.times { Class.new(parent) }
parent.define_singleton_method(:inherited) { |child| hooks << child }
a = Class.new(parent)
b = Class.new(parent)
check(hooks == [a, b])
parent.singleton_class.send(:remove_method, :inherited)
Class.new(parent)
check(hooks == [a, b])
GC.start
check(children[1].probe == 11)
check(fresh.mixed == 21)
puts 'pristine singleton cache mutations preserved'
