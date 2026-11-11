$VERBOSE = nil
$anonymous_existence_events = []
left = Class.new { def marker; :left; end }
right = Class.new { def marker; :right; end }
3.times { left.new; right.new }

# Warming inherited absence on different classes cannot hide a later core
# definition or a definition installed only on one of those classes.
class Object
  def initialize
    $anonymous_existence_events << :root
  end
end
left.new
right.new
p $anonymous_existence_events
left.class_eval do
  def initialize
    $anonymous_existence_events << :left
  end
end
$anonymous_existence_events.clear
left.new
right.new
p $anonymous_existence_events

mixin = Module.new do
  def initialize
    $anonymous_existence_events << :mixin
  end
end
right.include(mixin)
$anonymous_existence_events.clear
left.new
right.new
p $anonymous_existence_events

wrapper = Module.new do
  def initialize
    $anonymous_existence_events << :prepended
  end
end
left.prepend(wrapper)
8.times { GC.start }
$anonymous_existence_events.clear
left.new
right.new
p $anonymous_existence_events

# Existence lookups continue to notice per-class removal and undefinition.
left.send(:remove_method, :marker)
begin
  left.new.method(:marker)
rescue NameError
  puts :removed
end
p right.new.method(:marker).call
right.send(:undef_method, :marker)
p right.new.respond_to?(:marker)
$anonymous_existence_events = nil
