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
