target = Class.new { def marker; :base; end }
refinery = Module.new do
  refine target do
    def marker; :refined; end
  end
end
scope = Class.new do
  using refinery
  def read(object); object.marker; end
end
object = target.new
p [scope.new.read(object), object.marker]
p [scope.instance_method(:read).source_location.last, refinery.refinements.first.instance_method(:marker).source_location.last]
8.times { GC.start }
p scope.new.read(object)

# class_eval returns the declaration's value and restores the lexical table.
holder = Class.new
p holder.class_eval { using refinery; def read(object); object.marker; end }
p [holder.new.read(object), object.marker]

# Locals and global slots use the same lexical argument rule; an alias keeps
# the ordinary evaluator and is never treated as an unrelated global slot.
$native_declaration_target = target
$native_declaration_refinery = Module.new do
  refine $native_declaration_target do
    def marker; :global; end
  end
end
alias $native_declaration_alias $native_declaration_refinery
aliased = Class.new do
  using $native_declaration_alias
  def read(object); object.marker; end
end
p [aliased.new.read(object), object.marker]

# A constructor callback can install a singleton replacement before the
# declaration body starts. Its using method must receive the argument.
class << Object
  def inherited(child)
    child.define_singleton_method(:using) { |argument| @using_argument = argument }
  end
end
overridden = Class.new do
  using refinery
  def read(object); object.marker; end
end
p [overridden.new.read(object), overridden.instance_variable_get(:@using_argument).equal?(refinery)]
class << Object
  remove_method :inherited
end

# Hooks can observe the definition and must retain the normal class walker.
events = []
class << Object
  def inherited(child)
    child.define_singleton_method(:method_added) { |name| $native_declaration_events << name }
  end
end
$native_declaration_events = events
observed = Class.new do
  using refinery
  def read(object); object.marker; end
end
class << Object
  remove_method :inherited
end
p [events, observed.new.read(object)]
$native_declaration_target = $native_declaration_refinery = $native_declaration_events = nil
