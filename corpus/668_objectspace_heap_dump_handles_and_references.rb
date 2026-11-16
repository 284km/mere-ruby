require 'objspace'
require 'json'

object = Object.new
before = JSON.parse(ObjectSpace.dump(object))
raise 'object id observed too soon' if (before['flags'] || {}).key?('object_id')
identity = object.object_id
after = JSON.parse(ObjectSpace.dump(object))
raise 'observed object id missing' unless after.dig('flags', 'object_id') == identity

holder = Object.new
holder.instance_variable_set(:@child, object)
snapshot = ObjectSpace.dump_all(output: :string).lines.map { |line| JSON.parse(line) }
address = after.fetch('address')
raise 'object missing from snapshot' unless snapshot.any? { |row| row['address'] == address }
raise 'class missing from snapshot' unless snapshot.any? { |row| row['address'] == after['class'] }
raise 'reference missing from snapshot' unless snapshot.any? { |row| (row['references'] || []).include?(address) }

GC.disable
ObjectSpace.trace_object_allocations_start
GC.start
generation = GC.count
first = Object.new
GC.start
second = Object.new
rows = ObjectSpace.dump_all(output: :string, since: generation, shapes: false).lines.map { |line| JSON.parse(line) }
[first, second].each do |item|
  id = JSON.parse(ObjectSpace.dump(item)).fetch('address')
  raise 'traced object missing' unless rows.any? { |row| row['address'] == id }
end
raise 'untraced or older object included' unless rows.all? { |row| row['generation'] && row['generation'] >= generation }
ObjectSpace.trace_object_allocations_stop
GC.enable

raise 'uninitialized File type' unless JSON.parse(ObjectSpace.dump(File.allocate))['type'] == 'FILE'
%W[ascii Fée].each do |text|
  range = JSON.parse(ObjectSpace.dump(text)).fetch('coderange')
  raise 'incorrect encoding classification' unless range == (text.ascii_only? ? '7bit' : 'valid')
end
puts 'heap dumps preserve handles, references and allocation generations'
