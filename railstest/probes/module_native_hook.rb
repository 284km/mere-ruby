module ForwardIncluded
  def included(base)
    p [:before_native, base.name]
    result = super
    p [:native_result, result]
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
