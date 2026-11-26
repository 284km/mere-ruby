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
  p [:missing, error.class.name, error.name]
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
