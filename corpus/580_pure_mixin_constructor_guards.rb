[Class, Module].each do |factory|
  source = Module.new { def mixin_value; :mixed; end }
  created = factory.new { include source }
  raise unless created.ancestors.include?(source)
  receiver = factory == Class ? created.new : Object.new.extend(created)
  raise unless receiver.mixin_value == :mixed
  source.freeze
  raise unless factory.new { include source }.ancestors.include?(source)

  # Extra body statements, parameters and forwarded procs retain normal flow.
  seen = []
  factory.new { seen << :before; include source; seen << :after }
  raise unless seen == [:before, :after]
  raise unless factory.new { |identity| include source }.ancestors.include?(source)
  body = proc { include source }
  raise unless factory.new(&body).ancestors.include?(source)
  raise unless factory.new { prepend source }.ancestors.include?(source)

  invalid = Object.new
  begin
    factory.new { include invalid }
    raise 'expected module type error'
  rescue TypeError
  end
end

# Observable mixin callbacks run in order and can inspect the finished mixin.
source = Module.new
seen = []
source.define_singleton_method(:append_features) do |base|
  seen << :append
  super(base)
end
source.define_singleton_method(:included) do |base|
  seen << base.ancestors.include?(self)
end
Class.new { include source }
raise unless seen == [:append, true]

# inherited runs before the body resolves a captured module variable.
original = Module.new
alternate = Module.new
source = original
Object.define_singleton_method(:inherited) { |child| source = alternate }
created = Class.new { include source }
Object.singleton_class.send(:remove_method, :inherited)
raise unless created.ancestors.include?(alternate)
raise if created.ancestors.include?(original)
puts 'pure mixin constructor guards preserve callbacks and body evaluation'
