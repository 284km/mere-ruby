# Plain declarations keep lexical scope and observers when their block has no parent link.
module DeclarationLexical
  VALUE = :lexical
  C = Class.new do
    def token(value = VALUE) = value
  end
end
p DeclarationLexical::C.new.token
p DeclarationLexical::C.instance_method(:token).source_location.last

# A declaration does not capture block locals as method locals.
outer = :outer
klass = Class.new do
  def outer_value = defined?(outer)
end
p klass.new.outer_value
p outer

# The constructor's declarations remain public inside an outer private body.
module DeclarationVisibility
  private
  C = Class.new do
    def visible = :ok
  end
end
p DeclarationVisibility::C.public_instance_methods(false)

# The same registration handles refinement methods and their lexical constants.
class DeclarationTarget
  def token = :original
end
module DeclarationRefinery
  VALUE = :refined
  refine DeclarationTarget do
    def token = VALUE
  end
end
module DeclarationUsing
  using DeclarationRefinery
  def self.call = DeclarationTarget.new.token
end
p DeclarationUsing.call, DeclarationTarget.new.token

# A Ruby hook can observe the declaration's block environment.
events = []
base = Class.new do
  define_singleton_method(:inherited) do |child|
    child.define_singleton_method(:method_added) do |name|
      events << [name, caller_locations(0, 5).map(&:base_label).include?("new")]
    end
  end
end
observed = Class.new(base) do
  def observed = :observed
end
p events, observed.new.observed

# Frozen-class failures still restore lexical and refinement state.
freezing = Class.new do
  def self.inherited(child) = child.freeze
end
p(begin
  Class.new(freezing) do
    def refused = :no
  end
rescue FrozenError
  :frozen
end)
p DeclarationTarget.new.token
GC.start
p DeclarationLexical::C.new.token, DeclarationUsing.call
