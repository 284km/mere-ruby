module ConstantDecorator942
  def deprecate_constant(*names, **options)
    [names, options]
  end
end
[Class.new, Module.new].each do |owner|
  owner.singleton_class.prepend(ConstantDecorator942)
  p owner.deprecate_constant('OLD', 'NEW', deprecator: :token)
  owner.freeze
  p owner.deprecate_constant('OLD', 'NEW', deprecator: :token)
end

module NativeConstants942
  LIVE = 1
  class << self
    alias_method :saved_deprecation, :deprecate_constant
  end
end
Warning[:deprecated] = false
p NativeConstants942.deprecate_constant(:LIVE).equal?(NativeConstants942)
p NativeConstants942.saved_deprecation(:LIVE).equal?(NativeConstants942)
p NativeConstants942::LIVE
native = NativeConstants942.method(:saved_deprecation)
p native.call(:LIVE).equal?(NativeConstants942)
NativeConstants942.freeze
begin
  NativeConstants942.saved_deprecation(:LIVE)
rescue FrozenError => error
  p [error.class, error.receiver.equal?(NativeConstants942)]
end

module SuperConstants942
  LIVE = 2
  class << self
    def deprecate_constant(*names)
      @calls = (@calls || 0) + 1
      super
    end
    attr_reader :calls
  end
end
p SuperConstants942.deprecate_constant(:LIVE).equal?(SuperConstants942)
p SuperConstants942.calls
p SuperConstants942::LIVE

# Binding a method below Module must not jump back to its native method.
class Object
  def deprecate_constant(*names) = super
end
begin
  Object.instance_method(:deprecate_constant).bind(Module.new).call(:LIVE)
rescue NoMethodError => error
  p [:below_module, error.name]
end

# A Ruby replacement's super cannot recover the original Module method.
class Module
  def deprecate_constant(*names) = super
end
begin
  Module.new.deprecate_constant(:LIVE)
rescue NoMethodError => error
  p [:replacement, error.name]
end

module ForwardConstants942
  def deprecate_constant(*names) = super
end
Module.send(:undef_method, :deprecate_constant)
owner = Module.new
owner.singleton_class.prepend(ForwardConstants942)
begin
  owner.deprecate_constant(:LIVE)
rescue NoMethodError => error
  p [:undefined, error.name]
end
