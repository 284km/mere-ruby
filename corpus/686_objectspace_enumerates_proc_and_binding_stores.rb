require 'objspace'

GC.start
GC.disable
kept_proc = proc { :retained }
kept_binding = binding
sizes = []
[[Proc, kept_proc], [Binding, kept_binding]].each do |klass, target|
  seen = {}
  found = false
  returned = ObjectSpace.each_object(klass) do |object|
    raise 'class filter failed' unless object.is_a?(klass)
    raise 'duplicate identity' if seen.key?(object.object_id)
    seen[object.object_id] = true
    found ||= object.equal?(target)
  end
  raise 'held store object missing' unless found
  raise 'iteration count differs' unless returned == seen.size
  raise 'enumerator omits held object' unless ObjectSpace.each_object(klass).any? { |item| item.equal?(target) }
  sizes << returned
end
counts = ObjectSpace.count_objects
raise 'Proc/Binding data omitted from counts' unless counts.fetch(:T_DATA) >= sizes.sum
raise 'total omits data stores' unless counts[:TOTAL] >= counts[:T_DATA]
GC.enable
GC.start
raise 'held Proc lost after collection' unless ObjectSpace.each_object(Proc).any? { |item| item.equal?(kept_proc) }
raise 'held Binding lost after collection' unless ObjectSpace.each_object(Binding).any? { |item| item.equal?(kept_binding) }
puts 'ObjectSpace visits real Proc and Binding handles with consistent counts'
