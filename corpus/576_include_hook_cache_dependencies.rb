programs = [
  'm=Module.new; Class.new { include m }; seen=[]; m.define_singleton_method(:included) { |base| seen << base.ancestors.include?(self) }; Class.new { include m }; p seen',
  'm=Module.new; Class.new { include m }; seen=[]; m.define_singleton_method(:append_features) { |base| seen << :append; super(base); define_singleton_method(:included) { |b| seen << b.ancestors.include?(self) } }; Class.new { include m }; p seen',
  'm=Module.new; seen=[]; m.define_singleton_method(:included) { |base| seen << :included; define_singleton_method(:append_features) { |b| seen << :append; super(b) } }; 2.times { Class.new { include m } }; p seen',
  'Class.new { include Module.new }; seen=[]; Module.class_eval { define_method(:included) { |base| seen << base.ancestors.include?(self) } }; Class.new { include Module.new }; p seen',
  'm=Module.new; m.singleton_class; Class.new { include m }; hooks=Module.new { def included(base); puts :singleton_ancestor_hook; end }; m.singleton_class.include(hooks); Class.new { include m }',
  'm=Module.new; Class.new { include m }; m.define_singleton_method(:callback) { |base| puts :aliased_hook }; m.singleton_class.class_eval { alias_method :included, :callback }; Class.new { include m }',
  'm=Module.new; Class.new { include m }; GC.start; c=Class.new { include m }; p c.ancestors.include?(m); m.module_eval { def answer; 42; end }; p c.new.answer'
]
programs.each do |source|
  output = IO.popen([RbConfig.ruby, "-e", source], &:read)
  print output
  raise "include hook child failed" unless $?.success?
end
