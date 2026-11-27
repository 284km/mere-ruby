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

# A concern-style included block keeps all of its lexical modules when it
# defines a method on the consumer through class_eval.
module JobScope955
  Context = :lexical
  module Feature
    BODY = proc do
      def context955 = Context
      def nesting955 = Module.nesting.map(&:name)
    end
    SINGLE = proc do
      def context955 = [Context, Module.nesting.map(&:name)]
    end
    def self.included(base) = base.class_eval(&BODY)
  end
end
class JobConsumer955
  Context = :caller
  include JobScope955::Feature
end
p [:included_lexical, JobConsumer955.new.context955, JobConsumer955.new.nesting955]
p [:single_definition_lexical, Class.new(&JobScope955::Feature::SINGLE).new.context955]

# A qualified module opening has no enclosing lexical module, even though
# the same module path is printed. It must not see JobScope955::Context.
module JobScope955::Feature
  QUALIFIED = proc do
    def qualified_context955 = Context
  end
end
qualified955 = Class.new(&JobScope955::Feature::QUALIFIED)
begin
  qualified955.new.qualified_context955
rescue NameError => error
  p [:qualified_scope, error.class, error.name]
end
