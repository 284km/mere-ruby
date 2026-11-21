module PublishedNotification
  class << self
    public :included
  end
end
published = PublishedNotification.method(:included)
unbound_published = PublishedNotification.singleton_class.instance_method(:included)
p [:published, published.super_method, unbound_published.super_method]

module BeforePublishedNotification
  def included(base)
    [:before, super]
  end
end
PublishedNotification.singleton_class.prepend(BeforePublishedNotification)
visibility = PublishedNotification.method(:included).super_method
unbound_visibility = PublishedNotification.singleton_class.instance_method(:included).super_method
p [:visibility_owner, visibility.owner == PublishedNotification.singleton_class,
   visibility.super_method, unbound_visibility.owner == PublishedNotification.singleton_class,
   unbound_visibility.super_method]

module NotificationPrepend
  def included(base)
    [:wrapper, super]
  end
end
Module.prepend(NotificationPrepend)
target = Module.new
wrapper = target.method(:included)
native = wrapper.super_method
p [:bound, wrapper.owner, native.owner, native.call(Object), native.super_method]
unbound_wrapper = target.singleton_class.instance_method(:included)
unbound_native = unbound_wrapper.super_method
p [:unbound, unbound_wrapper.owner, unbound_native.owner,
   unbound_native.bind(target).call(Object), unbound_native.super_method]
saved = native
target.singleton_class.send(:undef_method, :included)
p [:saved_native, saved.call(Object), unbound_native.bind(target).call(Object)]

# A native Module entry can itself have a real Object super method. Its
# private visibility marker does not forward the native body to Object.
%i[included extended prepended const_added method_added method_removed method_undefined].each do |name|
  Object.send(:define_method, name) { |value| [:object_hook, name, value == Object] }
  receiver = Module.new
  bound = receiver.method(name)
  unbound = Module.instance_method(name)
  bound = bound.super_method until bound.owner == Module
  unbound = unbound.super_method until unbound.owner == Module
  p [:native_owner_with_super, name, bound.owner, bound.super_method.owner,
     bound.super_method.call(Object), unbound.super_method.owner,
     unbound.super_method.bind(receiver).call(Object)]
  Object.send(:remove_method, name)
end

# Class's native subclasses body is retained behind a Class prepend too.
# Asking the owner again would reselect the wrapper rather than that body.
module ClassNotificationPrepend
  def subclasses
    [:wrapper, super]
  end
end
Class.prepend(ClassNotificationPrepend)
class NotificationParent; end
class NotificationChild < NotificationParent; end
bound_wrapper = NotificationParent.method(:subclasses)
bound_native = bound_wrapper.super_method
unbound_wrapper = NotificationParent.singleton_class.instance_method(:subclasses)
unbound_native = unbound_wrapper.super_method
p [:class_bound, bound_wrapper.owner, bound_native.owner,
   bound_native.call, bound_native.super_method]
p [:class_unbound, unbound_wrapper.owner, unbound_native.owner,
   unbound_native.bind(NotificationParent).call, unbound_native.super_method]
p [:class_copies, bound_native.dup.call, bound_native.clone.call,
   bound_native.unbind.bind_call(NotificationParent),
   unbound_native.dup.bind_call(NotificationParent),
   unbound_native.clone.bind(NotificationParent).call]
