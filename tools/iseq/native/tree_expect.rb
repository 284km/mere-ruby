# tools/iseq/native/tree_expect.rb -- Prism's own tree, a line a node, and
# the serialized bytes the native reader is given (note 552 §11).
#   ruby tree_expect.rb <file.rb> <out.pm>     (under the reference ruby)
require "prism"
src = File.binread(ARGV[0])
File.binwrite(ARGV[1], Prism.dump(src))
r = Prism.parse(src)
puts "encoding #{r.source.source.encoding.name} errors #{r.errors.size}"
walk = lambda do |n|
  l = n.location
  puts "#{n.class.name.sub("Prism::", "")} #{n.node_id} #{l.start_line}:#{l.start_column}-#{l.end_line}:#{l.end_column} #{n.send(:flags)}"
  n.compact_child_nodes.each(&walk)
end
walk.(r.value)
