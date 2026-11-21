# Native Module mixin entries remain before a Ruby missing hook in super.
module NativeMixinWrappers
  def append_features(base)
    result = super
    raise 'append_features return changed' unless result.equal?(self)
    result
  end
  def prepend_features(base)
    result = super
    raise 'prepend_features return changed' unless result.equal?(self)
    result
  end
  def extend_object(target)
    result = super
    raise 'extend_object return changed' unless result.equal?(target)
    result
  end
end
module InstanceMissingMixin
  extend NativeMixinWrappers
  def method_missing(name, *args)
    raise "instance missing received #{name}"
  end
  def feature; :feature; end
end
p Class.new { include InstanceMissingMixin }.new.feature
p Class.new { prepend InstanceMissingMixin }.new.feature
p Object.new.extend(InstanceMissingMixin).feature
# A real singleton missing hook also cannot preempt an existing native entry.
def InstanceMissingMixin.method_missing(name, *args, &block)
  [:singleton_missing, name, args, block && block.call]
end
p Class.new { include InstanceMissingMixin }.new.feature
p InstanceMissingMixin.unknown(3) { :block }
module UnknownSuper
  def absent(*args, &block); super; end
end
module SingletonMissingReceiver
  extend UnknownSuper
  def self.method_missing(name, *args, &block)
    [:super_missing, name, args, block && block.call]
  end
end
p SingletonMissingReceiver.absent(4) { :forwarded }
frozen = Class.new.freeze
begin
  InstanceMissingMixin.send(:append_features, frozen)
rescue => error
  p error.class
end
begin
  InstanceMissingMixin.send(:prepend_features, 1)
rescue => error
  p error.class
end
