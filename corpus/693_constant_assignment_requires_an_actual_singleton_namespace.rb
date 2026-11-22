def capture(label)
  value = yield
  p [label, :ok, value]
rescue TypeError => e
  p [label, e.class, e.message]
end
[1, 2**100, 1.25, :word].each_with_index do |receiver, index|
  name = "SuiteScopeValue#{index}"
  capture([index, :direct]) { receiver.instance_eval("#{name} = 1") }
  capture([index, :branch]) { receiver.instance_eval("if true; #{name} = 1; end") }
  capture([index, :untaken]) { receiver.instance_eval("if false; #{name} = 1; end; :untaken") }
  capture([index, :iterator]) { receiver.instance_eval("1.times { #{name} = 1 }; :after") }
  capture([index, :proc]) { receiver.instance_eval("proc { #{name} = 1 }").call }
  capture([index, :new_string]) { receiver.instance_eval("Object.new.instance_eval('#{name} = 1'); :after") }
  Object.send(:remove_const, name) if Object.const_defined?(name, false)
end
capture(:outer_block) { 1.instance_eval { SuiteOuterBlockValue = 2 } }
p Object.const_defined?(:SuiteOuterBlockValue, false)
capture(:scoped) { 1.instance_eval('Object::SuiteScopedValue = 3') }
p Object::SuiteScopedValue
capture(:block_retarget) { Object.new.instance_eval('1.instance_eval { SuiteOtherBlockValue = 5 }') }
capture(:invalid_block_retarget) { 1.instance_eval('Object.new.instance_eval { SuiteInvalidBlockValue = 5 }') }
capture(:explicit_class_scope) { 1.instance_eval('class Object::SuiteExplicitScope; Value = 4; end; Object::SuiteExplicitScope::Value') }
