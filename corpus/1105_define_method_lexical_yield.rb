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

# Forwarding a body Proc must preserve its lexical block, rather than the
# registration helper's unrelated block or the eventual method caller's.
def forwarded_body_1105
  proc { yield }
end
def install_forwarded_1105(target, body, singleton)
  if singleton
    target.define_singleton_method(:forwarded, &body)
  else
    target.define_method(:forwarded, &body)
  end
end
definition = -> { :definition }
body = forwarded_body_1105(&definition)
[false, true].each do |singleton|
  target = singleton ? Object.new : Class.new
  install_forwarded_1105(target, body, singleton) { :registrar }
  receiver = singleton ? target : target.new
  p receiver.forwarded(&definition)
  p receiver.forwarded { :caller }
end

# Implicit super forwards the body's lexical block. An explicit block or
# &nil still overrides it, and the method's |&caller| remains the call block.
class LexicalSuperBase1105
  def save(*) = block_given? ? yield : :no_block
end

def lexical_super_factory_1105
  klass = Class.new(LexicalSuperBase1105)
  klass.define_method(:save) { |*args| super(*args) }
  klass
end

klass = lexical_super_factory_1105 { :definition_block }
p klass.new.save
p klass.new.save(1)
p klass.new.save { :caller_block }
without = lexical_super_factory_1105
p without.new.save { :caller_block }

class LexicalExplicitBase1105
  def implicit(*) = block_given? ? yield : :no_block
  alias explicit implicit
  alias empty implicit
  alias literal implicit
  alias nested implicit
end

def lexical_explicit_factory_1105
  klass = Class.new(LexicalExplicitBase1105)
  klass.define_method(:implicit) { |&caller| [super(), caller && caller.call] }
  klass.define_method(:explicit) { |&caller| super(&caller) }
  klass.define_method(:empty) { super(&nil) }
  klass.define_method(:literal) { super() { :literal_block } }
  klass.define_method(:nested) { 1.times.map { super() } }
  klass
end
object = lexical_explicit_factory_1105 { :definition_block }.new
p object.implicit { :caller_block }
p object.explicit { :caller_block }
p object.empty { :caller_block }
p object.literal { :caller_block }
p object.nested { :caller_block }

# A forwarded body Proc carries the block from its own defining method,
# rather than the unrelated registration helper.
def lexical_super_body_1105
  proc { |*args| super(*args) }
end
def lexical_super_install_1105(klass, body)
  klass.define_method(:save, &body)
end
klass = Class.new(LexicalSuperBase1105)
body = lexical_super_body_1105 { :definition_block }
lexical_super_install_1105(klass, body) { :registrar_block }
p klass.new.save { :caller_block }
GC.start
p klass.new.save
