# Each child starts before any constructor has been made private, so every
# writer is exercised independently of an earlier conservative fallback.
programs = [
  'Module.singleton_class.send(:private, :new); begin; Module.new; rescue NoMethodError; puts :private; end; p Module.send(:new).class; Module.singleton_class.send(:public, :new); p Module.new.class',
  'Class.private_class_method(:new); begin; Class.new; rescue NoMethodError; puts :private; end; p Class.send(:new).class; Class.public_class_method(:new); p Class.new.class',
  'class C; private; def new; 42; end; end; c=C.new; begin; c.new; rescue NoMethodError; puts :private; end; p c.send(:new)',
  'class C; private; define_method(:new) { 43 }; end; c=C.new; begin; c.new; rescue NoMethodError; puts :private; end; p c.send(:new)',
  'class C; private; def source; 44; end; alias new source; end; c=C.new; begin; c.new; rescue NoMethodError; puts :private; end; p c.send(:new)',
  'm=Module.new { private; def new; 45; end }; c=Class.new { include m }.new; begin; c.new; rescue NoMethodError; puts :private; end; p c.send(:new)'
]
programs.each do |source|
  output = IO.popen([RbConfig.ruby, "-e", source], &:read)
  print output
  raise "constructor child failed" unless $?.success?
end
