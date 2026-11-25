def factory_1105
  klass = Class.new do
    define_method(:run) { |&caller| [yield, caller && caller.call, block_given?, defined?(yield)] }
    define_method(:nested) { [1].map { yield } }
    define_method(:default) { |value = yield, &caller| [value, caller && caller.call] }
    define_method(:yield_defined) { defined?(yield) }
  end
  body = proc { yield }
  klass.define_method(:from_proc, body)
  klass.class_eval { alias copy run }
  object = klass.new
  object.define_singleton_method(:single) { |&caller| [yield, caller && caller.call] }
  object
end

object = factory_1105 { :definition }
GC.start
p object.run { :caller }
p object.run
p object.copy { :alias_caller }
p object.nested { :nested_caller }
p object.default { :default_caller }
p object.from_proc { :proc_caller }
p object.single { :singleton_caller }
p object.yield_defined

without = factory_1105
p without.yield_defined { :caller }
begin
  p without.run { :caller }
rescue LocalJumpError => error
  p [error.class, error.message]
end

def active_1105
  klass = Class.new { define_method(:run) { yield } }
  klass.new.run { :caller }
  :after
end
p(active_1105 { break :escaped })

orphan = factory_1105 { break :orphan_break }
begin
  orphan.run { :caller }
rescue LocalJumpError => error
  p [error.class, error.message]
end

lambda_object = factory_1105(&-> { break :lambda_value })
p lambda_object.nested { :caller }
