# Module's native notification entries remain real private methods when Ruby
# overrides delegate to them, including modules with an instance method_missing.
module ForwardIncluded
  def included(base)
    p [:included, base.name, defined?(super), super]
  end
end
module AttributeLike
  extend ForwardIncluded
  def method_missing(name, *args)
    raise "instance hook called on module for #{name}"
  end
end
class AttributeHost
  include AttributeLike
end
puts "included-ok"

hooks = %i[included extended prepended const_added method_added method_removed method_undefined]
hooks.each do |name|
  target = Module.new
  native = target.method(name)
  p [name, native.owner, native.arity, native.parameters,
     target.respond_to?(name), target.respond_to?(name, true)]
  p [:native, name, target.send(name, Object) { raise "ignored block" }]
  begin
    target.public_send(name, Object)
  rescue NoMethodError => error
    p [:private, error.name]
  end
  [[], [Object, Object]].each do |args|
    begin
      target.send(name, *args)
    rescue ArgumentError => error
      p [:arity, error.message]
    end
  end
  wrapper = Module.new
  wrapper.define_method(name) do |value|
    [:delegated, name, defined?(super), super(value)]
  end
  target.extend(wrapper)
  p target.send(name, Object)
  delegated = target.method(name).super_method
  p [:super_method, delegated.owner, delegated.arity, delegated.call(Object)]
  unbound = target.singleton_class.instance_method(name).super_method
  p [:unbound_super, unbound.owner, unbound.bind(target).call(Object)]
  p [:saved, native.call(Object)]
end

module AliasedNativeNotification
  class << self
    alias saved_included included
    public :saved_included
  end
end
p [:alias, AliasedNativeNotification.saved_included(Object)]
AliasedNativeNotification.singleton_class.send(:undef_method, :included)
p [:alias_after_undef, AliasedNativeNotification.saved_included(Object)]

module BeforeUndefinedNotification
  def included(base)
    p [:undefined_super, defined?(super)]
    super
  end
end
module UndefinedNotificationAncestor
  def included(base); end
  undef_method :included
end
module UndefinedNotification
  extend UndefinedNotificationAncestor
  extend BeforeUndefinedNotification
end
begin
  UndefinedNotification.send(:included, Object)
rescue NoMethodError => error
  p [:undefined, error.name]
end

# An Object ancestor is after Module's native entry and must not win lookup.
module AfterModuleNotification
  def included(base)
    raise "skipped native Module entry"
  end
end
Object.include(AfterModuleNotification)
p [:native_boundary, Module.new.send(:included, Object)]

# Replacing Module's own entry removes the native method from super lookup.
class Module
  def included(base)
    p [:replacement_super, defined?(super)]
    super
  end
end
begin
  Module.new.send(:included, Object)
rescue RuntimeError => error
  p [:replacement_boundary, error.message]
end
