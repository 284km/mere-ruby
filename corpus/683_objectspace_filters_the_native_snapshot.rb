require 'objspace'

module SnapshotMarker; end
class SnapshotText < String
  include SnapshotMarker
end
marked_class = Class.new
marked_class.extend(SnapshotMarker)
def marked_class.kind_of?(*) = false
text = SnapshotText.new('held text')
array = [text]
hash = { text => array }
[[String, text], [Array, array], [Hash, hash], [Class, marked_class]].each do |filter, held|
  found = false
  count = 0
  returned = ObjectSpace.each_object(filter) do |object|
    raise 'snapshot class filter failed' unless filter === object
    found ||= object.equal?(held)
    count += 1
  end
  raise 'held object omitted by filter' unless found
  raise 'filtered count disagrees' unless returned == count
end
marked = ObjectSpace.each_object(SnapshotMarker).to_a
raise 'String subclass module omitted' unless marked.any? { |o| o.equal?(text) }
raise 'extended class module omitted' unless marked.any? { |o| o.equal?(marked_class) }
group = Array.new(8) { [] }
ids = group.map(&:object_id)
seen = []
ObjectSpace.each_object(Array) do |object|
  if ids.include?(object.object_id)
    GC.start if seen.empty?
    seen << object.object_id
  end
end
raise 'held candidate group changed' unless group.size == ids.size
raise 'snapshot lost candidates during collection' unless seen.sort == ids.sort
begin
  ObjectSpace.each_object(Array) { raise ArgumentError, 'callback stopped' }
  raise 'callback error swallowed'
rescue ArgumentError => error
  raise 'callback error changed' unless error.message == 'callback stopped'
end
raise 'nested iteration failed' unless ObjectSpace.each_object(Array).any? { |o| ObjectSpace.each_object(Array).any? { |inner| inner.equal?(o) } }
token = Object.new
raise 'break result lost' unless ObjectSpace.each_object(Array) { break token }.equal?(token)
def leave_enumeration(token)
  ObjectSpace.each_object(Array) { return token }
  raise 'nonlocal return lost'
end
raise 'nonlocal result lost' unless leave_enumeration(token).equal?(token)
local_break = ->(_object) { break token }
raise 'lambda break escaped iteration' unless ObjectSpace.each_object(Array, &local_break).is_a?(Integer)
def orphan_iteration_block(token)
  proc { break token }
end
begin
  ObjectSpace.each_object(Array, &orphan_iteration_block(token))
  raise 'orphan break accepted'
rescue LocalJumpError => error
  raise 'orphan exit value lost' unless error.exit_value.equal?(token) && error.reason == :break
end
fiber = Fiber.new do
  ObjectSpace.each_object(Array) do |object|
    next unless object.equal?(array)
    Fiber.yield :paused
    break :resumed
  end
end
raise 'iteration did not suspend' unless fiber.resume == :paused
GC.start
raise 'suspended iteration lost its state' unless fiber.resume == :resumed
puts 'ObjectSpace filters real classes and value stores before yielding'
