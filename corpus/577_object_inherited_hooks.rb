programs = [
  'Class.new {}; seen=[]; Object.define_singleton_method(:inherited) { |child| seen << child.superclass.equal?(self) }; Class.new {}; Object.singleton_class.send(:remove_method, :inherited); Class.new {}; p seen',
  'Class.new {}; Object.define_singleton_method(:inherited) { |child| raise "hook failure" }; begin; Class.new { raise "body must not run" }; rescue RuntimeError => error; p error.message; end',
  'parent=Class.new; seen=[]; parent.define_singleton_method(:inherited) { |child| seen << child.superclass.equal?(self) }; Class.new(parent); p seen',
  'Class.new {}; seen=[]; trace=TracePoint.new(:c_call,:c_return) { |event| seen << event.event if event.method_id == :inherited }; trace.enable { Class.new {} }; p seen'
]
programs.each do |source|
  output = IO.popen([RbConfig.ruby, "-e", source], &:read)
  print output
  raise "inherited hook child failed" unless $?.success?
end
