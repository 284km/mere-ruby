require 'prism'
# An installed native Prism has no interpreter-specific helper methods.
if Prism.respond_to?(:__node_id_for_location)
  class << Prism
    remove_method :__node_id_for_location
  end
end

def backtrace_node_probe1004
  nil.missing_call1004
end

begin
  backtrace_node_probe1004
rescue NoMethodError => error
  location = error.backtrace_locations.first
  id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(location)
  queue = [Prism.parse_file(__FILE__).value]
  found = nil
  until queue.empty?
    node = queue.shift
    if node.node_id == id
      found = node
      break
    end
    queue.concat(node.compact_child_nodes)
  end
  p [found&.type, found&.name, found&.location&.start_line == location.lineno]
end
