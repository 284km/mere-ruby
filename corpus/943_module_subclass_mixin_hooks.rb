def ordinary_mixin943(label)
  mod = Module.new { def marker943 = :ordinary }
  klass = Class.new do
    include mod
    prepend mod
    extend mod
  end
  p [label, klass.new.marker943, klass.marker943,
     klass.ancestors.count { |entry| entry.equal?(mod) }]
end

ordinary_mixin943(:before_backing)

class HookModule943 < Module
  attr_accessor :events
  def append_features(base)
    events << :append
    events << super.equal?(self)
  end
  def included(base)
    events << :included
    super
  end
  def prepend_features(base)
    events << :prepend
    events << super.equal?(self)
  end
  def prepended(base)
    events << :prepended
    super
  end
  def extend_object(base)
    events << :extend_object
    events << super.equal?(base)
  end
  def extended(base)
    events << :extended
    super
  end
end
[:include, :prepend, :extend].each do |operation|
  mod = HookModule943.new
  mod.events = []
  mod.module_eval { def hook_value = 7 }
  receiver = operation == :extend ? Object.new : Class.new
  receiver.public_send(operation, mod)
  value = operation == :extend ? receiver.hook_value : receiver.new.hook_value
  p [operation, mod.events, value]
end

class PrivateHookModule943 < HookModule943
  private :append_features, :included, :prepend_features, :prepended, :extend_object, :extended
end
mod = PrivateHookModule943.new
mod.events = []
Class.new.include(mod)
Class.new.prepend(mod)
Object.new.extend(mod)
p mod.events

# A feature hook can install the notification that runs immediately after it.
class InstallingHook943 < Module
  attr_accessor :events
  def append_features(base)
    events << :append
    define_singleton_method(:included) { |owner| events << :new_included }
    super
  end
end
mod = InstallingHook943.new
mod.events = []
Class.new.include(mod)
p mod.events

# Multiple mixins run last first, preserving each original receiver's hook.
trace = []
a = HookModule943.new
b = HookModule943.new
a.events = trace
b.events = trace
Class.new.include(a, b)
p trace

ordinary_mixin943(:after_backing)
GC.start
ordinary_mixin943(:after_collection)
