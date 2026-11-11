klass = Class.new
object = klass.new
p object.respond_to?(:value)
klass.class_eval { def value; :first; end }
p object.value
held = object.method(:value)
klass.class_eval { remove_method :value }
p object.respond_to?(:value)
klass.class_eval { def value; :second; end }
p [object.value, held.call]
klass.class_eval { undef_method :value }
p object.respond_to?(:value)
klass.class_eval { def value; :third; end }
p [object.value, held.call]

aliased = Class.new do
  alias value to_s
  def value; :declared; end
end
p aliased.new.value

base = Class.new do
  private
  def inherited_value; :base; end
end
child = Class.new(base)
p child.new.respond_to?(:inherited_value)
child.class_eval { def inherited_value; :child; end }
p [child.new.inherited_value, child.public_instance_methods(false).include?(:inherited_value)]

missing = Class.new do
  def method_missing(name, *args)
    [name, args]
  end
end
p missing.new.unknown(:argument)
p 1.respond_to?(:unknown)

module FirstRefinement
  refine String do
    def first_marker; :refined; end
  end
end
class FirstRefinementCaller
  using FirstRefinement
  def self.call
    "value".first_marker
  end
end
p FirstRefinementCaller.call
