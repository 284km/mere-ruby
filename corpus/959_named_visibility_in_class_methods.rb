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
