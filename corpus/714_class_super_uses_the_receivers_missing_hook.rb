class ClassMissingHook
  def self.found(*args, **keywords, &block)
    super
  end
  def self.method_missing(name, *args, **keywords, &block)
    return [:class_hook, args, keywords, block && block.call(:yielded)] if name == :found
    super
  end
  def method_missing(*) = :instance_hook
end
p ClassMissingHook.found(7, key: 9) { |value| [:block, value] }
p ClassMissingHook.method(:found).call(8, other: 10) { :method_block }

class InheritedClassMissingHook < ClassMissingHook
end
p InheritedClassMissingHook.found(11) { :inherited }

module ExtendedMissingHook
  def method_missing(name, *args, **keywords, &block)
    return [:extended_hook, args, keywords, block && block.call] if name == :found
    super
  end
end
module MissingModuleReceiver
  extend ExtendedMissingHook
  def self.found(*args, **keywords, &block)
    super
  end
end
p MissingModuleReceiver.found(12, key: 13) { :module_block }

class RemovedClassTarget
  def self.found(*) = :must_not_run
  class << self
    undef_method :found
  end
end
class ChildOfRemovedClassTarget < RemovedClassTarget
  def self.found(*args, **keywords, &block)
    super
  end
  class << self
    private
    def method_missing(name, *args, **keywords, &block)
      return [:private_hook, args, keywords, block && block.call] if name == :found
      super
    end
  end
end
p ChildOfRemovedClassTarget.found(14, key: 15) { :tombstone }

class BlockSuppressedMissingHook < ClassMissingHook
  def self.found(*args, **keywords)
    super(*args, **keywords, &nil)
  end
end
p BlockSuppressedMissingHook.found(16) { :must_not_yield }

class ObjectMissingHook
  def found(*args, **keywords, &block)
    super
  end
  def method_missing(name, *args, **keywords, &block)
    return [:object_hook, args, keywords, block && block.call] if name == :found
    super
  end
end
p ObjectMissingHook.new.found(17, key: 18) { :object_block }

class NativeBeforeMissingHook
  def self.name
    super
  end
  def self.method_missing(*) = :must_not_replace_native
end
p NativeBeforeMissingHook.name

module NativeHookLayer
  def append_features(target)
    super
  end
  def included(target)
    super
  end
end
module NativeHooksBeforeMissing
  extend NativeHookLayer
  def self.method_missing(*)
    raise 'a native definition hook was replaced by method_missing'
  end
end
class NativeHookHost
  include NativeHooksBeforeMissing
end
p NativeHookHost.ancestors.include?(NativeHooksBeforeMissing)

module NativeIncludeTarget
end
class NativeIncludeBeforeMissing
  def self.include(*modules)
    super
  end
  def self.prepend(*modules)
    super
  end
  def self.method_missing(*)
    raise 'a native mixin operation was replaced by method_missing'
  end
end
p NativeIncludeBeforeMissing.include(NativeIncludeTarget).equal?(NativeIncludeBeforeMissing)
p NativeIncludeBeforeMissing.ancestors.include?(NativeIncludeTarget)
p NativeIncludeBeforeMissing.prepend(Module.new).equal?(NativeIncludeBeforeMissing)
