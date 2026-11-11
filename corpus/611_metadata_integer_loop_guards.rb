existing = nil
p(37.times do
  existing = Module.new
  Class.new { include existing }
end)
GC.start
p [existing.class, existing.name]

# Zero and negative counts leave captured locals untouched.
original = existing
0.times do
  existing = Module.new
  Class.new { include existing }
end
(-3).times do
  existing = Module.new
  Class.new { include existing }
end
p existing.equal?(original)

# Parameters and control flow retain the ordinary iterator path.
values = []
3.times do |index|
  existing = Module.new
  values << index
  Class.new { include existing }
end
p values
p(5.times do
  existing = Module.new
  Class.new { include existing }
  break :escaped
end)
begin
  2.times do
    existing = Module.new
    Class.new { include existing }
    raise 'visible loop exception'
  end
rescue RuntimeError => error
  p error.message
end

# An included callback observes every allocation and the correct edge.
$metadata_loop_events = []
class Module
  def included(base)
    $metadata_loop_events << base.ancestors.include?(self)
  end
end
4.times do
  existing = Module.new
  Class.new { include existing }
end
p $metadata_loop_events
$metadata_loop_events = nil
