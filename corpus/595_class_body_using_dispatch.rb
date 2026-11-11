refinery = Module.new do
  refine String do
    def using_marker; :local_refinement; end
  end
end
local_class = Class.new do
  using refinery
  def marker
    "value".using_marker
  end
end
p local_class.new.marker

$using_refinery = refinery
global_class = Class.new do
  using $using_refinery
  def marker
    "value".using_marker
  end
end
p global_class.new.marker
p "value".respond_to?(:using_marker)

custom = Class.new
custom.define_singleton_method(:using) do |argument|
  $using_custom_called = argument == refinery
end
custom.class_eval do
  using refinery
  def marker; :ordinary; end
end
p [$using_custom_called, custom.new.marker]

$invalid_using_refinery = 1
begin
  Class.new { using $invalid_using_refinery }
rescue TypeError
  p :invalid_refinery_refused
end
p "value".respond_to?(:using_marker)
