# First-inclusion shortcuts must retain the public dispatch and hook protocol.
events = []
leaf = Module.new
first = Class.new { include leaf }
raise 'first bare inclusion' unless first.ancestors.include?(leaf)
source = Module.new { def included_value; 42; end }
target = Class.new
raise 'include result' unless target.include(source).equal?(target)
raise 'included method' unless target.new.included_value == 42
frozen_source = Module.new.freeze
raise 'frozen source' unless Class.new.include(frozen_source).ancestors.include?(frozen_source)

frozen_target = Class.new.freeze
begin
  frozen_target.include(Module.new)
  raise 'frozen target accepted'
rescue FrozenError
  puts 'frozen target refused'
end

hooked = Module.new
hooked.define_singleton_method(:included) { |base| events << base }
target = Class.new
target.include(hooked)
raise 'included hook' unless events == [target]
puts 'included hook preserved'

Class.class_eval do
  define_method(:include) do |mod|
    events << :class_override
    frozen? ? :frozen_override : super(mod)
  end
end
begin
  source = Module.new
  target = Class.new
  raise 'class override result' unless target.include(source).equal?(target)
  raise 'class override' unless events.last == :class_override && target.ancestors.include?(source)
  raise 'frozen override' unless Class.new.freeze.include(Module.new) == :frozen_override
  Class.class_eval { private :include }
  target = Class.new
  begin
    target.include(Module.new)
    raise 'private include accepted'
  rescue NoMethodError
    puts 'private include refused'
  end
  raise 'private include via send' unless target.send(:include, Module.new).equal?(target)
ensure
  Class.class_eval { remove_method :include }
end
puts 'class override preserved'

Object.define_singleton_method(:include) { |mod| events << :object_override; :intercepted }
begin
  source = Module.new
  target = Class.new
  raise 'inherited override' unless target.include(source) == :intercepted
  raise 'override included source' if target.ancestors.include?(source)
ensure
  Object.singleton_class.class_eval { remove_method :include }
end
puts 'inherited override preserved'

calls = []
trace = TracePoint.new(:c_call) { |event| calls << event.method_id if event.method_id == :include }
trace.enable { Class.new.include(Module.new) }
raise 'include trace' unless calls == [:include]
puts 'include trace preserved'

target = Class.new
target.singleton_class.class_eval { undef_method :include }
begin
  target.include(Module.new)
  raise 'undefined include accepted'
rescue NoMethodError
  puts 'undefined include refused'
end
