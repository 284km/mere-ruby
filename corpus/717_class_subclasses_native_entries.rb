# Class native enumeration and Ruby definitions have separate entry points.
module CommandRegistry
  def self.subclasses
    @subclasses ||= []
  end
end
CommandRegistry.subclasses << :command
p [CommandRegistry.subclasses, CommandRegistry.instance_variable_get(:@subclasses)]
module RegistryArguments
  def self.subclasses(*args, **keywords, &block)
    [args, keywords, block&.call]
  end
end
p RegistryArguments.subclasses(1, flag: 2) { :block }
class RegistryParent
  def self.subclasses
    @registered ||= []
  end
end
class RegistryChild < RegistryParent; end
RegistryChild.subclasses << :child
p [RegistryParent.subclasses, RegistryChild.subclasses]

def direct_names(values)
  values.map { |value| value.is_a?(Class) ? value.name : value }.sort_by(&:to_s)
end

def refusal
  yield
rescue NoMethodError => error
  p [error.class, error.name, error.args]
rescue ArgumentError => error
  p [error.class, error.message]
end

class EnumeratedParent; end
class EnumeratedChild < EnumeratedParent; end
saved = EnumeratedParent.method(:subclasses)
unbound = Class.instance_method(:subclasses)
Class.class_eval { alias_method :saved_native_subclasses, :subclasses }
class << EnumeratedParent
  alias native_children subclasses
  def subclasses
    super + [:override]
  end
  alias ruby_children subclasses
end
p direct_names(EnumeratedParent.subclasses)
p direct_names(EnumeratedParent.subclasses { raise "native yielded" })
p direct_names(EnumeratedParent.native_children)
p direct_names(EnumeratedParent.native_children { raise "native alias yielded" })
p direct_names(EnumeratedParent.ruby_children)
p direct_names(saved.call)
p direct_names(saved.call { raise "saved native yielded" })
p direct_names(unbound.bind_call(EnumeratedParent))
p direct_names(unbound.bind(EnumeratedParent).call { raise "bound native yielded" })
[-> { saved.call(:bad) }, -> { EnumeratedParent.native_children(:bad) },
 -> { unbound.bind_call(EnumeratedParent, :bad) }].each { |call| refusal(&call) }
p [EnumeratedParent.method(:subclasses).owner == EnumeratedParent.singleton_class,
   saved.owner == Class, saved.source_location]

module BeforeEnumeration
  def subclasses
    super + [:prepended]
  end
end
EnumeratedParent.singleton_class.prepend(BeforeEnumeration)
p direct_names(EnumeratedParent.subclasses)
class EnumeratedGrandchild < EnumeratedChild; end
p direct_names(EnumeratedChild.subclasses)

class PrivateRegistry
  def self.subclasses
    [:private]
  end
  private_class_method :subclasses
end
refusal { PrivateRegistry.subclasses }
p PrivateRegistry.send(:subclasses)
class UndefRegistry; end
class UndefRegistryChild < UndefRegistry; end
saved_undefined = UndefRegistry.method(:subclasses)
class << UndefRegistry
  undef_method :subclasses
end
refusal { UndefRegistry.subclasses }
p direct_names(saved_undefined.call)
p direct_names(saved_undefined.call { raise "saved native yielded after undef" })
p direct_names(unbound.bind_call(UndefRegistry))
module OrdinaryModule; end
p OrdinaryModule.respond_to?(:subclasses)
refusal { OrdinaryModule.subclasses }

# A Ruby replacement of Class's own entry has no hidden native super.
begin
  Class.class_eval do
    def subclasses
      super
    end
  end
  p direct_names(saved.call { raise "saved native yielded after replacement" })
  p direct_names(EnumeratedParent.native_children)
  refusal { EnumeratedChild.subclasses }
ensure
  Class.send(:alias_method, :subclasses, :saved_native_subclasses)
end
p direct_names(EnumeratedChild.subclasses)

# Definitions and tombstones after Class must not bypass its native entry.
module AfterNativeClass
  def subclasses
    [:too_late]
  end
end
Class.include(AfterNativeClass)
p direct_names(EnumeratedChild.subclasses)
p direct_names(EnumeratedParent.subclasses)
p [EnumeratedChild.method(:subclasses).owner, direct_names(saved.call)]
AfterNativeClass.module_eval { undef_method :subclasses }
p direct_names(EnumeratedChild.subclasses)
p direct_names(EnumeratedParent.subclasses)
