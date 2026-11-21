# A Module subclass factory installs real instance methods from a closure.
class CapturedMethods < Module
  def initialize(defaults: {})
    include Enumerable
    define_method(:each) do |&block|
      defaults.each(&block)
      self
    end
    define_method(:lookup) { |key| defaults.fetch(key) }
    private :lookup
  end
end
factory = CapturedMethods.new(defaults: { one: 1, two: 2 })
klass = Class.new { include factory }
value = klass.new
p [factory.class, klass.ancestors.include?(factory), value.to_a,
   value.send(:lookup, :two), value.respond_to?(:lookup), value.respond_to?(:lookup, true)]
returned = factory.send(:define_method, :receiver) { self }
p [returned, value.receiver.equal?(value)]
factory.send(:define_method, :with_default) { |number = 7| number }
p [value.with_default, value.with_default(9)]
class OverriddenMethodFactory < Module
  def define_method(name, &body)
    [self.class, name, body.call]
  end
end
p OverriddenMethodFactory.new.define_method(:custom) { :override }
factory.freeze
begin
  factory.send(:define_method, :refused) { :never }
rescue => error
  p [error.class, factory.instance_methods(false).include?(:refused)]
end
plain = Module.new
plain.send(:define_method, :plain) { :normal }
p Class.new { include plain }.new.plain

# Visibility with no method names mutates no method entry on a frozen module.
p factory.send(:private)
begin
  factory.send(:private, :absent)
rescue => error
  p error.class
end
class VisibilityOverrideFactory < Module
  attr_reader :selection
  def private(*names); [self.class, names]; end
  def initialize
    @selection = private :missing
  end
end
p VisibilityOverrideFactory.new.selection
p OverriddenMethodFactory.new.freeze.define_method(:custom) { :still_override }
