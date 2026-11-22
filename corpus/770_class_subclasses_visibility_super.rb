# A singleton visibility entry represents an inherited body. Its super starts
# above that body, while a wrapper before it must still observe its owner.
def visibility_value(value)
  if value.is_a?(Class)
    value.name
  elsif value.is_a?(Array)
    values = value.map { |entry| visibility_value(entry) }
    value.all? { |entry| entry.is_a?(Class) } ? values.sort : values
  else
    value
  end
end

def visibility_chain(method, receiver)
  result = []
  while method
    value = method.is_a?(UnboundMethod) ? method.bind_call(receiver) : method.call
    result << [method.owner.to_s, visibility_value(value)]
    method = method.super_method
    raise 'super_method repeated a body' if result.length > 8
  end
  result
end

def visibility_methods(label, receiver)
  bound = receiver.method(:subclasses)
  unbound = receiver.singleton_class.instance_method(:subclasses)
  p [label, :bound, visibility_chain(bound, receiver)]
  p [label, :unbound, visibility_chain(unbound, receiver)]
  p [label, :copies, visibility_chain(bound.dup, receiver),
     visibility_chain(unbound.clone, receiver)]
end

class VisibilityParent
  class << self
    private :subclasses
  end
end
class VisibilityChild < VisibilityParent
  class << self
    protected :subclasses
  end
end
class VisibilityGrandchild < VisibilityChild; end
visibility_methods(:private, VisibilityParent)
visibility_methods(:protected, VisibilityChild)

module BeforeVisibility
  def subclasses
    [:before, super]
  end
end
VisibilityParent.singleton_class.prepend(BeforeVisibility)
visibility_methods(:singleton_prepend, VisibilityParent)

# A real Class prepend is the body represented by the visibility entry.
# After consuming it, the native Class body remains a distinct next method.
module BeforeClassVisibility
  def subclasses
    [:class_before, super]
  end
end
Class.prepend(BeforeClassVisibility)
visibility_methods(:class_prepend, VisibilityParent)
class PublishedVisibility < VisibilityChild
  class << self
    public :subclasses
  end
end
visibility_methods(:public, PublishedVisibility)

# Preserve ordinary Ruby bodies represented by an inherited visibility entry.
class RubyVisibilityParent
  def self.subclasses
    [:ruby]
  end
end
class RubyVisibilityChild < RubyVisibilityParent
  class << self
    private :subclasses
  end
end
RubyVisibilityChild.singleton_class.prepend(BeforeVisibility)
visibility_methods(:ruby_body, RubyVisibilityChild)
