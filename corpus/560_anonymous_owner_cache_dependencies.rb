mix = Module.new { def value; 1; end }
parent = Class.new { include mix }
child = Class.new(parent)
object = child.new
raise unless object.value == 1 && object.respond_to?(:value)
mix.module_eval { def value; 2; end }
raise unless object.value == 2
raise if object.respond_to?(:later)
mix.module_eval { def later; 3; end }
raise unless object.respond_to?(:later) && object.later == 3

extra = Module.new { def extra; 4; end }
before = child.ancestors
parent.include(extra)
raise unless child.ancestors.include?(extra) && !before.include?(extra)
raise unless object.extra == 4
front = Module.new { def value; super + 10; end }
parent.prepend(front)
raise unless object.value == 12
mix.module_eval { def value; 5; end }
raise unless object.value == 15

copy = mix.dup
copy.module_eval { def value; 6; end }
raise unless Class.new { include copy }.new.value == 6
raise unless object.value == 15
mix.module_eval { remove_method :later }
raise if object.respond_to?(:later)

singleton_parent = Class.new
singleton_parent.define_singleton_method(:answer) { 20 }
singleton_child = Class.new(singleton_parent)
raise unless singleton_child.answer == 20
singleton_parent.define_singleton_method(:answer) { 21 }
raise unless singleton_child.answer == 21
raise if singleton_child.respond_to?(:added)
singleton_parent.define_singleton_method(:added) { 22 }
raise unless singleton_child.added == 22

MroDependencyHost = Class.new { include mix }
raise unless MroDependencyHost.new.value == 5
mix.module_eval { def value; 7; end }
raise unless MroDependencyHost.new.value == 7 && object.value == 17
GC.start
raise unless singleton_child.answer == 21 && object.value == 17
[:include, :prepend].each do |mode|
  leaf = Module.new
  begin
    leaf.send(mode, leaf)
    raise 'self cycle accepted'
  rescue ArgumentError
  end
  left = Module.new
  right = Module.new
  left.send(mode, right)
  begin
    right.send(mode, left)
    raise 'indirect cycle accepted'
  rescue ArgumentError
  end
end
puts "anonymous cache dependencies preserved"
