programs = [
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; replacement=Module.new; Module.define_singleton_method(:new) { replacement }; made=code.call; Module.singleton_class.send(:remove_method,:new); p made.ancestors.include?(replacement)',
  'existing=nil; code=proc { existing=Module.new; Class.new { include existing } }; code.call; alternate=Module.new; Object.define_singleton_method(:inherited) { |child| existing=alternate }; made=code.call; Object.singleton_class.send(:remove_method,:inherited); p made.ancestors.include?(alternate)',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; seen=[]; Module.class_eval { define_method(:included) { |base| seen << base.ancestors.include?(self) } }; code.call; p seen',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; Module.singleton_class.send(:private,:new); begin; code.call; rescue NoMethodError; puts :private_new_refused; ensure; Module.singleton_class.send(:public,:new); end; p code.call.is_a?(Class)',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; holder=Class.new; holder.class_eval { alias_method :new, :to_s }; p code.call.is_a?(Class)',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; holder=Class.new; holder.class_eval { def new; end; undef_method :new }; p code.call.is_a?(Class)',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; seen=[]; point=TracePoint.new(:line) { seen << :line }; point.enable { code.call }; p !seen.empty?',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; p Thread.new { code.call }.value.is_a?(Class)',
  'code=proc { scratch=Module.new; Class.new { include scratch } }; code.call; p code.binding.local_variable_defined?(:scratch)'
]
programs.each do |source|
  output = IO.popen([RbConfig.ruby, '-e', source], &:read)
  print output
  raise 'metadata lookup child failed' unless $?.success?
end
