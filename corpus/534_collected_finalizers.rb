# A finalizer made in a separate scope does not capture the target.
# Use a batch: conservative native stack scans may retain some nearby handles.
# Collection must deliver unreachable callbacks once; exact timing of any one
# target is deliberately not asserted.
$finalized = []
def callback(label)
  proc { |id| $finalized << [label, id] }
end
def make_garbage(label)
  Array.new(100) do
    obj = Object.new
    id = obj.object_id.to_s
    ObjectSpace.define_finalizer(obj, callback(label))
    id
  end
end
def collect_until
  30.times do
    100.times { Object.new }
    GC.start
    break if yield
  end
end
ids = Fiber.new { make_garbage(:dead) }.resume
collect_until { $finalized.any? { |label, oid| label == :dead } }
dead = $finalized.select { |label, _| label == :dead }.map { |_, oid| oid.to_s }
p [:collected, !dead.empty? && dead.uniq == dead && dead.all? { |id| ids.include?(id) }]
live = Object.new
live_id = live.object_id
cb = callback(:live)
p [:duplicate, ObjectSpace.define_finalizer(live, cb)[1].equal?(ObjectSpace.define_finalizer(live, cb)[1])]
5.times { GC.start }
p [:reachable, !$finalized.any? { |_, oid| oid == live_id }]
ObjectSpace.undefine_finalizer(live)
live = nil
5.times { GC.start }
p [:undefined, !$finalized.any? { |_, oid| oid == live_id }]
# Captured targets remain reachable through their callback's binding.
def captured
  obj = Object.new
  cb = proc { |id| $finalized << [:captured, id]; obj }
  ObjectSpace.define_finalizer(obj, cb)
  cb
end
kept = captured
5.times { GC.start }
p [:captured, !$finalized.any? { |label, _| label == :captured }]
ObjectSpace.undefine_finalizer(kept.binding.local_variable_get(:obj))
# A dead copy inherits callbacks, while the source remains reachable.
def copy_garbage(source)
  Array.new(100) { source.dup.object_id.to_s }
end
source = Object.new
ObjectSpace.define_finalizer(source, callback(:copy))
copy_ids = Fiber.new { copy_garbage(source) }.resume
collect_until { $finalized.any? { |label, oid| label == :copy && copy_ids.include?(oid.to_s) } }
p [:copy, $finalized.any? { |label, oid| label == :copy && copy_ids.include?(oid.to_s) }]
ObjectSpace.undefine_finalizer(source)
