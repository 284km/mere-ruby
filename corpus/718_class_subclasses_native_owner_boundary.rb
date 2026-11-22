class NativeParent; end
class NativeChild < NativeParent; end
saved = NativeParent.method(:subclasses)
unbound = Class.instance_method(:subclasses)
module AfterClass
  def subclasses
    [:after_class]
  end
end
Class.include(AfterClass)
p NativeParent.subclasses.map(&:name)
p NativeParent.method(:subclasses).owner
class Class
  def subclasses
    super + [:class_replacement]
  end
end
p NativeParent.subclasses
p saved.call.map(&:name)
p unbound.bind_call(NativeParent).map(&:name)
