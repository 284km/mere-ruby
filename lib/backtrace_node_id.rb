# frozen_string_literal: true

# Interpreter-owned backtrace metadata, using only Prism's public Node API.
# This also works when an installed native Prism supplies the parser.
module RubyVM::AbstractSyntaxTree
  # The interpreter maps a backtrace location to a Prism node for
  # error_highlight finds the node a frame was running (its prism_find parses
  # the file and looks for this id). ruby reads the id off the instruction the
  # frame stopped at; here there is no Prism node behind the evaluator and no
  # column in a frame, so the node is picked from the file's Prism tree: among
  # the calls (and the constants, the operator writes, the defs) the line
  # holds, the one named for the call the frame was making -- @__callee on the
  # Location, which Exception#backtrace_locations writes: the method of the
  # frame inside it, or the innermost frame's NameError name. A frame named
  # like a def on its line is that def (an ArgumentError's callee). With no
  # name to go by, the line's only call. -1 when there is no file, and when
  # more than one node answers: the line and a name do not tell two calls of
  # one name apart.
  class << self
    def __node_id_for_location(loc) # :nodoc:
      path = loc.absolute_path
      return -1 unless path && File.file?(path)
      stat = File.stat(path)
      line = loc.lineno
      want = loc.instance_variable_get(:@__callee)
      own = loc.base_label.to_s.to_sym
      key = [path, stat.mtime, stat.size, line, want, own]
      ids = (@__nid_ids ||= {})
      return ids[key] if ids.key?(key)

      # Cache only the answer. Keeping a complete native Prism tree here
      # duplicates the tree error_highlight builds immediately afterwards.
      cands = []
      __nid_walk(Prism.parse_file(path).value, line, cands)
      tiers =
        if want == :"(entry)"
          # (the frame an ArgumentError of the arguments was raised entering:
          #  the def, or the lambda / block define_method was given)
          [cands.select { |n| n.type == :def_node && n.name == own },
           cands.select { |n| n.type == :lambda_node || n.type == :block_node }]
        else
          [want ? cands.select { |n| __nid_call?(n) && __nid_names(n).include?(want) } : [],
           # (a method written in C has a frame of its own, on its caller's
           #  line, named for the method: Integer#+)
           cands.select { |n| __nid_call?(n) && __nid_names(n).include?(own) },
           cands.select { |n| n.type == :call_node },
           cands.select { |n| __nid_call?(n) }]
        end
      # (the first way of asking that finds anything decides, and it must
      #  find ONE: `'a'.upcase; nil.upcase` has two calls named upcase on
      #  the line, and which one raised is not known here -- -1, no node,
      #  rather than a call that succeeded)
      found = tiers.find { |t| !t.empty? }
      # (...but an operator write and the constant path it writes are one
      #  construct, not two calls: `::X += 1` answers the write, as ruby's id
      #  does)
      if found && found.size > 1
        targets = found.filter_map { |n| n.target.node_id if n.respond_to?(:target) }
        found = found.reject { |n| targets.include?(n.node_id) }
      end
      id = found && found.size == 1 ? found[0].node_id : -1
      ids.shift if ids.size >= 128
      ids[key] = id
    end

    private

    NID_TYPES = %i[call_node call_operator_write_node call_and_write_node call_or_write_node
                   index_operator_write_node index_and_write_node index_or_write_node
                   local_variable_operator_write_node instance_variable_operator_write_node
                   global_variable_operator_write_node class_variable_operator_write_node
                   constant_read_node constant_path_node constant_operator_write_node
                   constant_path_operator_write_node def_node lambda_node block_node].freeze
    private_constant :NID_TYPES

    # (children first: the order the line's calls are evaluated in. A call
    #  is on the line of its name, as ruby numbers it, or -- as this
    #  interpreter numbers a call whose receiver is on an earlier line --
    #  on the line it starts on)
    def __nid_walk(node, line, out)
      return unless node.location.start_line <= line && node.location.end_line >= line
      node.compact_child_nodes.each { |child| __nid_walk(child, line, out) }
      return unless NID_TYPES.include?(node.type)
      loc = (node.respond_to?(:message_loc) && node.message_loc) || node.location
      out << node if loc.start_line == line || node.location.start_line == line
    end

    def __nid_call?(node)
      node.type != :def_node && node.type != :lambda_node && node.type != :block_node
    end

    # The method names a node calls.
    def __nid_names(node)
      case node.type
      when :call_node, :constant_read_node, :constant_path_node, :def_node then [node.name]
      when :call_operator_write_node then [node.read_name, node.write_name, node.binary_operator]
      when :call_and_write_node, :call_or_write_node then [node.read_name, node.write_name]
      when :index_operator_write_node then [:[], :[]=, node.binary_operator]
      when :index_and_write_node, :index_or_write_node then [:[], :[]=]
      when :constant_operator_write_node then [node.name, node.binary_operator]
      when :constant_path_operator_write_node then [node.target.name, node.binary_operator]
      else [node.binary_operator]
      end
    end
  end
end
