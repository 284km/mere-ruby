class ModuleProbe955 < Module
  attr_reader :tag
  def initialize(tag) = @tag = tag
  def ==(other) = other.is_a?(ModuleProbe955) && tag == other.tag
end

first = ModuleProbe955.new(1)
klass = Class.new
klass.include(first)
listed = klass.included_modules.first
p [:reflection, listed.equal?(first), listed.class == ModuleProbe955]
p [:ancestors, klass.ancestors.include?(first)]
p [:equality, klass.included_modules.include?(ModuleProbe955.new(1))]

klass = Class.new
before = klass.ancestors.length
[1, 1, 2, 2].each do |tag|
  mod = ModuleProbe955.new(tag)
  klass.include(mod) unless klass.included_modules.include?(mod)
end
p [:growth, klass.ancestors.length - before]

# Ordinary modules still expose their original identity, and a module's
# included_modules omits the receiver while exposing nested module objects.
ordinary = Module.new
nested = ModuleProbe955.new(3)
outer = ModuleProbe955.new(4)
outer.include(nested)
klass = Class.new
klass.include(ordinary)
klass.prepend(outer)
p [:ordinary, klass.included_modules.include?(ordinary)]
p [:nested, outer.included_modules.first.equal?(nested)]
p [:receiver, outer.included_modules.any? { |mod| mod.equal?(outer) }]
