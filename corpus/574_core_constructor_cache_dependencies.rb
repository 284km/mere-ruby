# Each child starts with cold constructor caches and independent core classes.
programs = [
  'Module.new; Module.define_singleton_method(:new) { :module_override }; p Module.new; Module.singleton_class.send(:remove_method, :new); p Module.new.class',
  'Class.new {}; Class.define_singleton_method(:new) { :class_override }; p Class.new { raise "must not run" }; Class.singleton_class.send(:remove_method, :new); p Class.new {}.class',
  'm=Module.new; Module.singleton_class.include(m); p Module.new.class; m.module_eval { def new; :module_mixin; end }; p Module.new; m.module_eval { def new; :module_replaced; end }; p Module.new; m.module_eval { remove_method :new }; p Module.new.class',
  'a=Module.new; b=Module.new { include a }; Class.singleton_class.include(b); p Class.new {}.class; a.module_eval { def new; :ancestor_override; end }; p Class.new {}; a.module_eval { remove_method :new }; p Class.new {}.class',
  'Class.new {}; Class.define_singleton_method(:factory) { :aliased_factory }; Class.singleton_class.class_eval { alias_method :new, :factory }; p Class.new {}; Class.singleton_class.send(:remove_method, :new); Class.singleton_class.send(:remove_method, :factory); p Class.new {}.class',
  'Module.new; Module.singleton_class.send(:undef_method, :new); begin; Module.new; rescue NoMethodError; puts :undefined_constructor; end'
]
programs.each do |source|
  output = IO.popen([RbConfig.ruby, "-e", source], &:read)
  print output
  raise "constructor child failed" unless $?.success?
end
