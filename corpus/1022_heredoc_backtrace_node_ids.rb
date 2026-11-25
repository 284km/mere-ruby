require 'prism'
def heredoc_call1022(*args) = args
x = nil
2.times do
  begin
    heredoc_call1022(<<~TEXT)
      #{x.foo}
    TEXT
  rescue NoMethodError => error
    id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(error.backtrace_locations.first)
    nodes = [Prism.parse_file(__FILE__).value]
    node = nil
    until nodes.empty?
      current = nodes.shift
      node = current if current.node_id == id
      nodes.concat(current.compact_child_nodes)
    end
    p [node&.type, node.respond_to?(:name) ? node.name : nil]
  end
end
