$seen_finalizers = []
$finalizer_depth = 0
$max_finalizer_depth = 0
$spawned_finalizers = false

def nested_finalizer
  proc { |id| $seen_finalizers << [:nested, id] }
end

def new_targets(callback)
  100.times { ObjectSpace.define_finalizer(Object.new, callback) }
end

def collecting_finalizer
  proc do |id|
    $finalizer_depth += 1
    $max_finalizer_depth = [$max_finalizer_depth, $finalizer_depth].max
    $seen_finalizers << [:outer, id]
    unless $spawned_finalizers
      $spawned_finalizers = true
      new_targets(nested_finalizer)
    end
    100.times { [Object.new, "allocation"] }
    GC.start
    raise "callback failure"
  ensure
    $finalizer_depth -= 1
  end
end

$VERBOSE = nil
Fiber.new { new_targets(collecting_finalizer) }.resume
begin
  raise "outer exception"
rescue => outer
  30.times do
    GC.start
    break if $seen_finalizers.any? { |kind, _| kind == :nested }
  end
  p [:exception_restored, $!.equal?(outer)]
end
p [:collected, $seen_finalizers.any? { |kind, _| kind == :outer }]
p [:registered_during_callback, $seen_finalizers.any? { |kind, _| kind == :nested }]
p [:once, $seen_finalizers == $seen_finalizers.uniq]
p [:not_reentrant, $max_finalizer_depth == 1, $finalizer_depth == 0]

callback = Object.new
class << callback
  private
  def call(id)
    $seen_finalizers << [:private, id]
  end
end
Fiber.new { new_targets(callback) }.resume
30.times do
  GC.start
  break if $seen_finalizers.any? { |kind, _| kind == :private }
end
p [:private_callback, $seen_finalizers.any? { |kind, _| kind == :private }]
