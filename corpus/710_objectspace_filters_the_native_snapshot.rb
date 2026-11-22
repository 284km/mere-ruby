require 'objspace'

raise 'blockless enumeration changed' unless ObjectSpace.each_object.is_a?(Enumerator)
begin
  ObjectSpace.each_object(Array, Hash)
  raise 'extra filter accepted'
rescue ArgumentError
end
begin
  ObjectSpace.each_object(1).next
  raise 'invalid filter accepted'
rescue TypeError
end
def yield_from_enumeration
  ObjectSpace.each_object(Array) { yield; break :outer_yield }
end
calls = 0
raise 'outer block lost' unless yield_from_enumeration { calls += 1 } == :outer_yield && calls == 1
module SnapshotMarker; end
class SnapshotPlain; end
class SnapshotText < String
  include SnapshotMarker
end
class SnapshotArray < Array
  include SnapshotMarker
end
class SnapshotHash < Hash
  include SnapshotMarker
end
marked_class = Class.new
marked_class.extend(SnapshotMarker)
def marked_class.kind_of?(*) = false
text = SnapshotText.new('held text')
array = [text]
hash = { text => array }
[[String, text], [Array, array], [Hash, hash], [Class, marked_class], [Class, SnapshotPlain]].each do |filter, held|
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
[[Array, SnapshotArray], [Hash, SnapshotHash]].each do |base, child|
  value = child.new
  [base, child, SnapshotMarker].each do |filter|
    raise 'value-store ancestry filter changed' unless ObjectSpace.each_object(filter).any? { |o| o.equal?(value) }
  end
end
[Array, Hash].each do |base|
  child = Class.new(base)
  value = child.new
  value.extend(SnapshotMarker)
  [base, child, SnapshotMarker].each do |filter|
    raise 'singleton-tagged ancestry filter changed' unless ObjectSpace.each_object(filter).any? { |o| o.equal?(value) }
  end
end
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
ephemeral_class = Class.new
held_candidate = ephemeral_class.new
previous_disabled = GC.disable
begin
  1000.times { ephemeral_class.new }
  visited = 0
  held_seen = false
  returned = ObjectSpace.each_object(ephemeral_class) do |object|
    visited += 1
    held_seen ||= object.equal?(held_candidate)
    if visited == 1
      GC.enable
      GC.start
      raise 'current candidate collected in its callback' unless ephemeral_class === object
    end
  end
  raise 'enumeration retained every unheld candidate' unless visited < 1001
  raise 'held candidate lost after collection' unless held_seen
  raise 'live iteration count disagrees' unless returned == visited
ensure
  previous_disabled ? GC.disable : GC.enable
end
# Non-main enumeration must preserve Ractor isolation even through the
# public Ruby wrapper, its Enumerator and typed value-store filters.
Warning[:experimental] = false
main_only = Object.new
raise 'main object omitted before Ractor' unless ObjectSpace.each_object(Object).any? { |o| o.equal?(main_only) }
shared_text = 'snapshot shared text'.freeze
shared_array = [shared_text].freeze
shared_hash = { token: shared_text }.freeze
result = Ractor.new(shared_text, shared_array, shared_hash) do |text, array, hash|
  [Object, String, Array, Hash].each do |filter|
    visible_count = 0
    visible_returned = ObjectSpace.each_object(filter) do |object|
      raise 'unshareable object crossed Ractor enumeration' unless Ractor.shareable?(object)
      visible_count += 1
    end
    raise 'Ractor enumeration count disagrees' unless visible_returned == visible_count
  end
  raise 'Enumerator crossed Ractor isolation' if ObjectSpace.each_object.any? { |o| !Ractor.shareable?(o) }
  [[String, text], [Array, array], [Hash, hash]].each do |filter, held|
    raise 'shared value omitted inside Ractor' unless ObjectSpace.each_object(filter).any? { |o| o.equal?(held) }
  end
  :isolated_snapshot
end.value
raise 'Ractor enumeration did not complete' unless result == :isolated_snapshot
raise 'Ractor context leaked to main' unless Ractor.main?
def ObjectSpace.each_object(*) = :overridden
raise 'user override ignored' unless ObjectSpace.each_object == :overridden
puts 'ObjectSpace filters real classes and value stores before yielding'
