# A builtin-backed method is still a method of the class, so reflection has to
# see it. zeitwerk takes Module.instance_method(:name) and bind_calls it to
# read a module's real name past any override -- that is how dry-logic loads.
module Foo
  module Inner; end
end

m = Module.instance_method(:name)
p m.class
p m.bind_call(Foo)
p m.bind(Foo).call
p m.bind_call(Foo::Inner)
p Module.instance_method(:ancestors).bind_call(Foo).include?(Foo)

p UnboundMethod.method_defined?(:bind_call)
p UnboundMethod.method_defined?(:bind)
p Module.method_defined?(:name)
p Module.method_defined?(:ancestors)
p String.method_defined?(:upcase)
p Array.method_defined?(:each)
p String.method_defined?(:no_such_method_here)

# an overridden `name` wins for a direct call, as in Ruby
module Shadow
  def self.name = "lying"
end
p Shadow.name

# user methods and privacy are unchanged
class C
  def pub; end
  private
  def priv; end
end
p C.method_defined?(:pub)
p C.method_defined?(:priv)
p C.private_method_defined?(:priv)
p C.instance_method(:pub).class
p String.instance_method(:upcase).bind_call("ab")
