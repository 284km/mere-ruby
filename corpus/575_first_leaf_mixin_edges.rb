def report_mix(c, m)
  p c.ancestors.count { |x| x.equal?(m) }
end
m = Module.new
parent = Class.new
child = Class.new(parent) { include m }
parent.include(m)
report_mix(child, m)

m = Module.new
parent = Class.new { include m }
GC.start
child = Class.new(parent) { include m }
report_mix(child, m)

m = Module.new
parent = Class.new { prepend m }
child = Class.new(parent) { include m }
report_mix(child, m)

inner = Module.new
outer = Module.new { include inner }
c = Class.new { include outer }
report_mix(c, inner)
report_mix(c, outer)

m = Module.new
c = Class.new { include m }
o = c.new
p o.respond_to?(:later)
m.module_eval { def later; :defined_later; end }
p o.later

m = Module.new
c = Class.new.freeze
begin
  c.include(m)
rescue FrozenError
  p :frozen_target
end
m = Module.new
begin
  m.include(m)
rescue ArgumentError
  p :cyclic_include
end

m = Module.new
seen = []
m.define_singleton_method(:included) { |base| seen << base.ancestors.include?(self) }
Class.new { include m }
p seen
