class GuardedParent
  def self.subclasses
    p defined?(super)
    defined?(super) ? super : []
  end
end
class GuardedChild < GuardedParent; end
p GuardedParent.subclasses.map(&:name)
method = GuardedParent.method(:subclasses).super_method
p [method.owner, method.call.map(&:name)]
unbound = GuardedParent.singleton_class.instance_method(:subclasses).super_method
p [unbound.owner, unbound.bind(GuardedParent).call.map(&:name)]
class BlockedParent; end
class << BlockedParent
  undef_method :subclasses
end
class GuardedBlocked < BlockedParent
  def self.subclasses
    [defined?(super), defined?(super) ? super : []]
  end
end
p GuardedBlocked.subclasses
class Class
  def subclasses
    p defined?(super)
    defined?(super) ? super : []
  end
end
p GuardedParent.subclasses
p method.call.map(&:name)
