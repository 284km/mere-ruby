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

      # Index one file once, retaining only compact call metadata. No Prism
      # node or source tree survives, and another file replaces this index.
      index_key = key[0, 3]
      unless @__nid_index_key == index_key
        index = {}
        __nid_index(Prism.parse_file(path).value, index)
        @__nid_index_key = index_key
        @__nid_index = index
      end
      cands = @__nid_index[line] || []
      tiers =
        if want == :"(entry)"
          # (the frame an ArgumentError of the arguments was raised entering:
          #  the def, or the lambda / block define_method was given)
          [cands.select { |n| n[0] == :def_node && n[2].include?(own) },
           cands.select { |n| n[0] == :lambda_node || n[0] == :block_node }]
        elsif want
          # A recorded callee must match. An eval filename can name a file
          # containing entirely different code; unrelated nodes are no fallback.
          [cands.select { |n| __nid_call?(n) && n[2].include?(want) }]
        else
          [[],
           # (a method written in C has a frame of its own, on its caller's
           #  line, named for the method: Integer#+)
           cands.select { |n| __nid_call?(n) && n[2].include?(own) },
           cands.select { |n| n[0] == :call_node },
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
        targets = found.filter_map { |n| n[3] }
        found = found.reject { |n| targets.include?(n[1]) }
      end
      id = found && found.size == 1 ? found[0][1] : -1
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
    def __nid_index(node, index)
      # Heredoc bodies can lie outside a parent call's location.
      node.compact_child_nodes.each { |child| __nid_index(child, index) }
      return unless NID_TYPES.include?(node.type)
      loc = (node.respond_to?(:message_loc) && node.message_loc) || node.location
      target = node.target.node_id if node.respond_to?(:target)
      entry = [node.type, node.node_id, __nid_names(node), target]
      [loc.start_line, node.location.start_line].uniq.each do |line|
        (index[line] ||= []) << entry
      end
    end

    def __nid_call?(entry)
      entry[0] != :def_node && entry[0] != :lambda_node && entry[0] != :block_node
    end

    # The method names a node calls.
    def __nid_names(node)
      case node.type
      when :lambda_node, :block_node then []
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
