module VisibilityBuilder
  def install(handler)
    define_method(:from_handler, &handler)
    private :from_handler
  end

  def publish
    public :from_handler
  end

  def protect
    protected :from_handler
  end

  def hide_missing
    private :missing
  end
end

class VisibilityTarget
  extend VisibilityBuilder

  def self.install_direct
    define_method(:direct) { :direct }
    private :direct
  end
end

VisibilityTarget.install(-> { :handler })
VisibilityTarget.install_direct
p [:private, VisibilityTarget.private_instance_methods(false).sort]
p [:public_handler, VisibilityTarget.public_instance_methods(false).include?(:from_handler)]
p [:private_call, VisibilityTarget.new.send(:from_handler)]

VisibilityTarget.publish
p [:published, VisibilityTarget.new.public_send(:from_handler)]
VisibilityTarget.protect
p [:protected, VisibilityTarget.protected_instance_methods(false)]

module VisibilityModule
  extend VisibilityBuilder
end
VisibilityModule.install(-> { :module_handler })
p [:module, VisibilityModule.private_instance_methods(false)]

begin
  VisibilityTarget.hide_missing
rescue NameError => error
  p [:missing, error.class.name]
end

VisibilityTarget.freeze
begin
  VisibilityTarget.publish
rescue FrozenError => error
  p [:frozen, error.class.name, error.receiver.equal?(VisibilityTarget)]
end

def top_level_visibility_control
  :top_level
end
private :top_level_visibility_control
p [:top_level, Object.private_instance_methods(false).include?(:top_level_visibility_control)]

class CustomVisibility959
  def self.private(name)
    name
  end

  def self.run
    private :arbitrary
  end
end
p [:custom_private, CustomVisibility959.run]
CustomVisibility959.freeze
p [:frozen_custom_private, CustomVisibility959.run]

module NamedVisibilityCalls959
  def run_private959
    private :arbitrary
  end

  def run_public959
    public :arbitrary
  end

  def run_protected959
    protected :arbitrary
  end
end

class OverriddenVisibility959
  extend NamedVisibilityCalls959

  def self.private(*names)
    [:own_private, names, block_given?]
  end

  def self.public(*names)
    [:own_public, names, block_given?]
  end

  def self.protected(*names)
    [:own_protected, names, block_given?]
  end
end

[:run_private959, :run_public959, :run_protected959].each do |name|
  p [:own_override, name, OverriddenVisibility959.send(name) { :caller_block }]
end
OverriddenVisibility959.freeze
[:run_private959, :run_public959, :run_protected959].each do |name|
  p [:frozen_override, name, OverriddenVisibility959.send(name) { :caller_block }]
end

class InheritedVisibility959 < OverriddenVisibility959
end
[:run_private959, :run_public959, :run_protected959].each do |name|
  p [:inherited_override, name, InheritedVisibility959.send(name)]
end

module NamedVisibilityOverrides959
  def private(*names)
    [:extended_private, names, block_given?]
  end

  def public(*names)
    [:extended_public, names, block_given?]
  end

  def protected(*names)
    [:extended_protected, names, block_given?]
  end
end

module ExtendedVisibility959
  extend NamedVisibilityCalls959
  extend NamedVisibilityOverrides959
end
ExtendedVisibility959.freeze
[:run_private959, :run_public959, :run_protected959].each do |name|
  p [:extended_override, name, ExtendedVisibility959.send(name) { :caller_block }]
end

# AMQP keeps a collection of method classes in its own .methods. Reflection
# must not replace that Ruby method with a list of Symbols.
class ReflectionOverride959
  def self.methods(all = true)
    [:own_methods, all, block_given?]
  end

  def self.public_methods(all = true) = [:own_public_methods, all]
  def self.private_methods(all = true) = [:own_private_methods, all]
  def self.protected_methods(all = true) = [:own_protected_methods, all]
end
class InheritedReflection959 < ReflectionOverride959; end
[:methods, :public_methods, :private_methods, :protected_methods].each do |name|
  p [:reflection_override, name, ReflectionOverride959.send(name, false)]
  p [:inherited_reflection, name, InheritedReflection959.send(name)]
end
p [:reflection_block, ReflectionOverride959.methods(false) { :caller_block }]

module ReflectionMixin959
  def methods(all = true) = [:extended_methods, all]
end
module ExtendedReflection959
  extend ReflectionMixin959
end
p [:extended_reflection, ExtendedReflection959.methods(false)]

class ReflectionSuper959
  def self.marker959 = :marker
  NATIVE_METHODS = method(:methods)
  class << self
    alias native_methods959 methods
  end

  def self.methods(all = true)
    [:own_super, super(all).include?(:marker959)]
  end
end
p [:reflection_super, ReflectionSuper959.methods(false)]
p [:retained_reflection, ReflectionSuper959::NATIVE_METHODS.call(false).include?(:marker959)]
p [:aliased_reflection, ReflectionSuper959.native_methods959(false).include?(:marker959)]

class PrivateReflection959
  class << self
    private
    def methods = [:private_methods_override]
  end
end
begin
  PrivateReflection959.methods
rescue NoMethodError => error
  p [:private_reflection, error.class, error.name]
end
p [:private_reflection_send, PrivateReflection959.send(:methods)]
