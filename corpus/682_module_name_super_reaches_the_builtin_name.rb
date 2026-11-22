module NativeNameSuper
  def name(*args, &block)
    super
  end
end
class GemNamedClass
  extend NativeNameSuper
end
module GemNamedModule
  extend NativeNameSuper
end
p [GemNamedClass.name, GemNamedModule.name]
name = GemNamedClass.name
p [name.frozen?, name.equal?(GemNamedClass.name)]
anonymous = Class.new
anonymous.extend(NativeNameSuper)
p anonymous.name
GemLateName = anonymous
p anonymous.name
anonymous_module = Module.new
anonymous_module.extend(NativeNameSuper)
p anonymous_module.name
singleton = GemNamedClass.singleton_class
singleton.extend(NativeNameSuper)
p singleton.name
[GemNamedClass, GemNamedModule, anonymous_module].each do |type|
  begin
    type.name(:extra)
  rescue ArgumentError => error
    p [error.class, error.message]
  end
end
p GemNamedClass.name { raise 'ignored block' }

# A tombstone between the override and Module still stops super.
parent = Class.new
parent.singleton_class.send(:undef_method, :name)
blocked = Class.new(parent)
def blocked.name
  super
end
begin
  blocked.name
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(blocked)]
end

# Replacing Module's own entry leaves no native name above that method.
class Module
  alias original_name_for_gem_suite name
  def name(*args)
    super
  end
end
begin
  [GemNamedClass, GemNamedModule].each do |type|
    begin
      type.name
    rescue NoMethodError => error
      p [error.name, error.args, error.receiver.equal?(type)]
    end
  end
ensure
  class Module
    remove_method :name
    alias name original_name_for_gem_suite
    remove_method :original_name_for_gem_suite
  end
end
p GemNamedClass.name
