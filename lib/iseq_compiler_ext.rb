# frozen_string_literal: true
#
# RubyVM::InstructionSequence's compiler, as mere-ruby has it (note 548): a
# port of ruby 4.0.9's prism_compile.c and the backend of compile.c it uses
# (the instruction list, labels, trace events, operand unification, the
# specialised opt_* instructions) and iseq.c's to_a and disasm. Its input is
# Prism's tree -- the parser ruby 4.0 compiles from -- so the instructions,
# their lines and their events are the ones ruby chooses.
#
# A node this compiler does not know yet is a NotImplementedError naming it:
# it never answers with instructions it did not derive. The instructions
# are executed by the VM as it grows (note 548 §2); until then an ISeq's
# #eval runs its source the way the rest of the program runs.
require "prism"

class RubyVM::InstructionSequence
  module Compiler__
    VM_ENV_DATA_SIZE = 3
    CALL_ARGS_SPLAT = 1
    CALL_ARGS_BLOCKARG = 2
    CALL_FCALL = 4
    CALL_VCALL = 8
    CALL_ARGS_SIMPLE = 16
    CALL_KWARG = 32
    CALL_KW_SPLAT = 64
    CALL_FLAG_NAMES = [[CALL_ARGS_SPLAT, "ARGS_SPLAT"], [CALL_ARGS_BLOCKARG, "ARGS_BLOCKARG"],
                       [CALL_FCALL, "FCALL"], [CALL_VCALL, "VCALL"], [CALL_ARGS_SIMPLE, "ARGS_SIMPLE"],
                       [CALL_KWARG, "KWARG"], [CALL_KW_SPLAT, "KW_SPLAT"]].freeze

    EVENT_BITS = { line: 0x01, class: 0x02, end: 0x04, call: 0x08, return: 0x10,
                   c_call: 0x20, c_return: 0x40, b_call: 0x100, b_return: 0x200 }.freeze
    EVENT_TO_A = { line: :RUBY_EVENT_LINE, class: :RUBY_EVENT_CLASS, end: :RUBY_EVENT_END,
                   call: :RUBY_EVENT_CALL, return: :RUBY_EVENT_RETURN,
                   b_call: :RUBY_EVENT_B_CALL, b_return: :RUBY_EVENT_B_RETURN }.freeze
    EVENT_DISASM = [[:line, "Li"], [:class, "Cl"], [:end, "En"], [:call, "Ca"], [:return, "Re"],
                    [:c_call, "Cc"], [:c_return, "Cr"], [:b_call, "Bc"], [:b_return, "Br"]].freeze

    # opt_* that a simple send with this many arguments becomes
    # (compile.c's iseq_specialized_instruction)
    SPECIAL0 = { length: :opt_length, size: :opt_size, empty?: :opt_empty_p, nil?: :opt_nil_p,
                 succ: :opt_succ, "!": :opt_not }.freeze
    SPECIAL1 = { "+": :opt_plus, "-": :opt_minus, "*": :opt_mult, "/": :opt_div, "%": :opt_mod,
                 "==": :opt_eq, "!=": :opt_neq, "=~": :opt_regexpmatch2, "<": :opt_lt, "<=": :opt_le,
                 ">": :opt_gt, ">=": :opt_ge, "<<": :opt_ltlt, "[]": :opt_aref, "&": :opt_and,
                 "|": :opt_or }.freeze
    SPECIAL2 = { "[]=": :opt_aset }.freeze

    Label = Struct.new(:id, :pos, :refs)
    Insn = Struct.new(:name, :ops, :line, :node_id, :events)
    CallData = Struct.new(:mid, :flag, :argc, :kwargs)

    # one instruction sequence being built, and what to_a / disasm read off it
    class Unit
      attr_reader :type, :label, :path, :abs_path, :first_lineno, :locals, :params,
                  :children, :elements, :code_location, :node_id, :parent
      attr_accessor :stack_max

      def initialize(type, label, path, abs_path, first_lineno, locals, parent, code_location, node_id)
        @type, @label, @path, @abs_path, @first_lineno = type, label, path, abs_path, first_lineno
        @locals, @parent, @code_location, @node_id = locals, parent, code_location, node_id
        @params = { lead_num: 0 }
        @children = []
        @elements = []
        @labels = 0
        @pending = []
        @line = first_lineno
        @node = nil
        @stack_max = 0
        @last_line = nil
        @loops = []
      end

      # (prism_compile.c: a line event only where the line changed since the
      #  last one -- ISEQ_COMPILE_DATA(iseq)->last_line -- and the scope's
      #  leave is on that line)
      attr_accessor :last_line
      attr_reader :loops

      def new_label = Label.new(@labels += 1, nil, 0)
      def emit_label(l) = @elements << l
      def event(e) = @pending << e
      def at(line, node_id) = (@line, @node = line, node_id)
      def line = @line

      def insn(name, *ops)
        i = Insn.new(name, ops, @line, @node, @pending)
        @pending = []
        @elements << i
        i
      end

      def depth
        d, u = 0, self
        d += 1 while (u = u.parent) && u.type == :block
        d
      end

      def level_of(name)
        lv, u = 0, self
        while u
          return [lv, u] if u.locals.include?(name)
          u = u.type == :block ? u.parent : nil
          lv += 1
        end
        nil
      end
    end

    module_function

    # -- entry ---------------------------------------------------------------
    def compile(src, path, abs_path, line, label = "<compiled>")
      result = Prism.parse(src, filepath: path, line: line)
      raise SyntaxError, result.errors.map(&:message).join("\n") unless result.success?
      root = result.value
      l = root.location
      unit = Unit.new(:top, label, path, abs_path, line, root.locals, nil,
                      [l.start_line, l.start_column, l.end_line, l.end_column], root.node_id)
      compile_body(unit, root.statements, root.node_id)
      finish(unit)
      unit
    end

    # (the scope's `leave` is the scope node's, on its closing line when it
    #  has one -- a def's `end`, a block's `}` -- and the last line otherwise)
    def compile_body(unit, stmts, node_id, end_line = nil)
      if stmts.nil? || stmts.body.empty?
        unit.at(unit.line, node_id)
        unit.insn(:putnil)
      else
        node(unit, stmts, false)
      end
      if unit.type == :method
        unit.event(:return)
      elsif unit.type == :block
        unit.event(:b_return)
      end
      unit.last_line = end_line if end_line
      unit.at(unit.last_line || unit.line, node_id)
      unit.insn(:leave)
    end

    # -- nodes ---------------------------------------------------------------
    def node(u, n, popped)
      u.at(n.location.start_line, n.node_id)
      if n.newline? && u.last_line != n.location.start_line
        u.last_line = n.location.start_line
        u.event(:line)
      end
      case n
      when Prism::StatementsNode
        body = n.body
        body.each_with_index { |s, i| node(u, s, popped || i < body.size - 1) }
      when Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode, Prism::SymbolNode
        u.insn(:putobject, n.value) unless popped
      when Prism::NilNode then u.insn(:putnil) unless popped
      when Prism::TrueNode then u.insn(:putobject, true) unless popped
      when Prism::FalseNode then u.insn(:putobject, false) unless popped
      when Prism::SelfNode then u.insn(:putself) unless popped
      when Prism::StringNode
        unless popped
          if n.frozen?
            u.insn(:putobject, n.unescaped.dup.freeze)
          else
            u.insn(:putchilledstring, n.unescaped.dup.freeze)
          end
        end
      when Prism::ArrayNode then array(u, n, popped)
      when Prism::LocalVariableReadNode
        u.insn(:getlocal, *local_ref(u, n.name, n.depth)) unless popped
      when Prism::LocalVariableWriteNode
        node(u, n.value, false)
        here(u, n)
        u.insn(:dup) unless popped
        u.insn(:setlocal, *local_ref(u, n.name, n.depth))
      when Prism::LocalVariableOperatorWriteNode
        u.insn(:getlocal, *local_ref(u, n.name, n.depth))
        node(u, n.value, false)
        here(u, n)
        u.insn(:send, CallData.new(n.binary_operator, CALL_ARGS_SIMPLE, 1, nil), nil)
        u.insn(:dup) unless popped
        u.insn(:setlocal, *local_ref(u, n.name, n.depth))
      when Prism::CallNode then call(u, n, popped)
      when Prism::IfNode, Prism::UnlessNode then branch(u, n, popped)
      when Prism::WhileNode, Prism::UntilNode then loop_node(u, n, popped)
      when Prism::DefNode then define(u, n, popped)
      when Prism::BreakNode then break_node(u, n)
      when Prism::ParenthesesNode
        if n.body then node(u, n.body, popped) else (u.insn(:putnil) unless popped) end
      else
        raise NotImplementedError, "RubyVM::InstructionSequence: #{n.type} is not compiled yet"
      end
    end

    # an instruction is the node's that emits it: after its children a node
    # marks its own place again
    def here(u, n) = u.at(n.location.start_line, n.node_id)

    def local_ref(u, name, depth)
      lv, owner = u.level_of(name)
      raise NotImplementedError, "local #{name} not found" unless owner
      idx = owner.locals.size - owner.locals.index(name) + VM_ENV_DATA_SIZE - 1
      [LocalOp.new(name, owner.locals.index(name), idx), lv]
    end

    LocalOp = Struct.new(:name, :index, :idx)

    def static_literal?(n)
      case n
      when Prism::IntegerNode, Prism::FloatNode, Prism::SymbolNode, Prism::NilNode,
           Prism::TrueNode, Prism::FalseNode, Prism::RationalNode, Prism::ImaginaryNode
        true
      when Prism::StringNode then n.frozen?
      when Prism::ArrayNode then n.elements.all? { |e| static_literal?(e) }
      else false
      end
    end

    def static_value(n)
      case n
      when Prism::ArrayNode then n.elements.map { |e| static_value(e) }.freeze
      when Prism::NilNode then nil
      when Prism::TrueNode then true
      when Prism::FalseNode then false
      when Prism::StringNode then n.unescaped.dup.freeze
      else n.value
      end
    end

    def array(u, n, popped)
      if n.elements.any? { |e| e.is_a?(Prism::SplatNode) }
        raise NotImplementedError, "RubyVM::InstructionSequence: splat in an array is not compiled yet"
      end
      if !n.elements.empty? && n.elements.all? { |e| static_literal?(e) }
        u.insn(:duparray, static_value(n)) unless popped
      else
        n.elements.each { |e| node(u, e, popped) }
        u.insn(:newarray, n.elements.size) unless popped
      end
    end

    def call(u, n, popped)
      flag = 0
      if n.receiver
        node(u, n.receiver, false)
      else
        u.insn(:putself)
        flag |= CALL_FCALL
      end
      args = n.arguments ? n.arguments.arguments : []
      if args.any? { |a| a.is_a?(Prism::SplatNode) || a.is_a?(Prism::KeywordHashNode) || a.is_a?(Prism::BlockArgumentNode) } ||
         n.block.is_a?(Prism::BlockArgumentNode)
        raise NotImplementedError, "RubyVM::InstructionSequence: this call's arguments are not compiled yet"
      end
      args.each { |a| node(u, a, false) }
      flag |= CALL_VCALL if n.variable_call?
      flag |= CALL_ARGS_SIMPLE unless n.block.is_a?(Prism::BlockNode)
      here(u, n)
      cd = CallData.new(n.name, flag, args.size, nil)
      if n.block.is_a?(Prism::BlockNode)
        blk = block_unit(u, n.block)
        u.insn(:send, cd, blk)
      else
        u.insn(:send, cd, nil)
      end
      u.insn(:pop) if popped
    end

    def block_unit(u, b)
      method_unit = u
      method_unit = method_unit.parent while method_unit.type == :block
      levels = u.depth + 1
      label = levels == 1 ? "block in #{method_unit.label}" : "block (#{levels} levels) in #{method_unit.label}"
      l = b.location
      child = Unit.new(:block, label, u.path, u.abs_path, l.start_line, b.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], b.node_id)
      params(child, b.parameters.is_a?(Prism::BlockParametersNode) ? b.parameters.parameters : nil, b.parameters)
      u.children << child
      child.at(l.start_line, b.node_id)
      child.event(:b_call)
      compile_body(child, b.body.is_a?(Prism::StatementsNode) ? b.body : nil, b.node_id, l.end_line)
      finish(child)
      child
    end

    # (a block's one parameter and nothing else -- `|y|`, not `|y,|` -- is
    #  ambiguous_param0: the block takes an Array's first element or the
    #  whole value, as yield passes it)
    def params(unit, ps, outer)
      return unless ps
      if ps.optionals.any? || (ps.rest && !ps.rest.is_a?(Prism::ImplicitRestNode)) || ps.posts.any? ||
         ps.keywords.any? || ps.keyword_rest || ps.block
        raise NotImplementedError, "RubyVM::InstructionSequence: these parameters are not compiled yet"
      end
      unit.params[:lead_num] = ps.requireds.size
      if unit.type == :block && ps.requireds.size == 1 && ps.rest.nil?
        unit.params[:ambiguous_param0] = true
      end
    end

    def define(u, n, popped)
      raise NotImplementedError, "RubyVM::InstructionSequence: a singleton def is not compiled yet" if n.receiver
      l = n.location
      child = Unit.new(:method, n.name.to_s, u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      params(child, n.parameters, nil)
      u.children << child
      body = n.body
      first = body.is_a?(Prism::StatementsNode) ? body.body.first : nil
      child.at(first ? first.location.start_line : l.start_line, n.node_id)
      child.event(:call)
      if body.is_a?(Prism::StatementsNode)
        node(child, body, false)
      elsif body.nil?
        child.insn(:putnil)
      else
        node(child, body, false)
      end
      child.event(:return)
      child.last_line = l.end_line
      child.at(child.last_line, n.node_id)
      child.insn(:leave)
      finish(child)
      here(u, n)
      u.insn(:definemethod, n.name, child)
      u.insn(:putobject, n.name) unless popped
    end

    def branch(u, n, popped)
      unless_ = n.is_a?(Prism::UnlessNode)
      then_body = n.statements
      else_body = unless_ ? n.else_clause&.statements : (n.subsequent.is_a?(Prism::ElseNode) ? n.subsequent.statements : n.subsequent)
      l_else = u.new_label
      l_end = u.new_label
      node(u, n.predicate, false)
      u.insn(unless_ ? :branchif : :branchunless, l_else)
      l_else.refs += 1
      if then_body then node(u, then_body, popped) else (u.insn(:putnil) unless popped) end
      if else_body || !popped
        u.insn(:jump, l_end)
        l_end.refs += 1
        u.emit_label(l_else)
        if else_body
          node(u, else_body, popped)
        else
          u.insn(:putnil) unless popped
        end
        u.emit_label(l_end)
      else
        u.emit_label(l_else)
      end
    end

    # prism_compile.c's pm_compile_loop: the next / redo / break labels,
    # the adjust block a `next` lands in, and the condition at the bottom;
    # compile.c's peephole turns `branchunless end; jump redo` into one
    # `branchif redo` (`branchunless` for until)
    def loop_node(u, n, popped)
      until_ = n.is_a?(Prism::UntilNode)
      raise NotImplementedError, "RubyVM::InstructionSequence: a begin/end while is not compiled yet" if n.begin_modifier?
      next_l = u.new_label
      redo_l = u.new_label
      break_l = u.new_label
      end_l = u.new_label
      u.insn(:jump, next_l); next_l.refs += 1
      u.insn(:putnil)
      u.insn(:pop)
      u.insn(:jump, next_l); next_l.refs += 1
      u.emit_label(redo_l)
      u.loops.push([next_l, break_l, redo_l])
      node(u, n.statements, true) if n.statements
      u.loops.pop
      u.emit_label(next_l)
      node(u, n.predicate, false)
      u.insn(until_ ? :branchunless : :branchif, redo_l); redo_l.refs += 1
      u.emit_label(end_l)
      here(u, n)
      u.insn(:putnil)
      u.emit_label(break_l)
      u.insn(:pop) if popped
    end

    def break_node(u, n)
      lp = u.loops.last or raise NotImplementedError, "RubyVM::InstructionSequence: break out of a block is not compiled yet"
      args = n.arguments&.arguments || []
      raise NotImplementedError, "RubyVM::InstructionSequence: break with values" if args.size > 1
      if args.empty? then u.insn(:putnil) else node(u, args[0], false) end
      here(u, n)
      u.insn(:jump, lp[1]); lp[1].refs += 1
    end

    # -- the backend: specialise, unify, lay out ---------------------------
    def finish(u)
      els = u.elements
      # a send with no block and plain arguments is opt_send_without_block,
      # or one of the opt_* that the VM answers for the builtin classes
      els.each do |e|
        next unless e.is_a?(Insn) && e.name == :send && e.ops[1].nil?
        cd = e.ops[0]
        if cd.flag & (CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KWARG | CALL_KW_SPLAT) == 0 && cd.flag & CALL_ARGS_SIMPLE != 0
          sp = case cd.argc
               when 0 then SPECIAL0[cd.mid]
               when 1 then SPECIAL1[cd.mid]
               when 2 then SPECIAL2[cd.mid]
               end
          sp = nil if cd.flag & CALL_FCALL != 0
          if sp
            e.name = sp
            e.ops = [cd]
            e.events = e.events + [:c_call, :c_return]
            next
          end
        end
        e.name = :opt_send_without_block
        e.ops = [cd]
      end
      # operand unification (defs/opt_operand.def)
      els.each do |e|
        next unless e.is_a?(Insn)
        case e.name
        when :getlocal, :setlocal
          if e.ops[1] == 0 || e.ops[1] == 1
            e.name = :"#{e.name}_WC_#{e.ops[1]}"
            e.ops = [e.ops[0]]
          end
        when :putobject
          if e.ops[0].equal?(0) || e.ops[0].equal?(1)
            e.name = :"putobject_INT2FIX_#{e.ops[0]}_"
            e.ops = []
          end
        end
      end
      # positions
      pos = 0
      els.each do |e|
        if e.is_a?(Label) then e.pos = pos
        else pos += 1 + e.ops.size
        end
      end
      u.stack_max = stack_max(u)
    end

    def stack_max(u)
      depth = max = 0
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        pop, push = stack_effect(e)
        depth -= pop
        depth += push
        max = depth if depth > max
      end
      max
    end

    def stack_effect(e)
      case e.name
      when :putnil, :putself, :putobject, :putchilledstring, :putstring, :duparray,
           :getlocal, :getlocal_WC_0, :getlocal_WC_1, :putobject_INT2FIX_0_, :putobject_INT2FIX_1_
        [0, 1]
      when :setlocal, :setlocal_WC_0, :setlocal_WC_1, :pop, :branchif, :branchunless then [1, 0]
      when :dup then [1, 2]
      when :newarray then [e.ops[0], 1]
      when :opt_send_without_block, :send then [e.ops[0].argc + 1, 1]
      when :leave then [1, 0]
      when :definemethod, :jump then [0, 0]
      else
        if e.name.to_s.start_with?("opt_")
          [e.ops[0].argc + 1, 1]
        else
          [0, 0]
        end
      end
    end

    # -- to_a ----------------------------------------------------------------
    def to_a(u)
      misc = { arg_size: u.params[:lead_num], local_size: u.locals.size, stack_max: u.stack_max,
               node_id: u.node_id, code_location: u.code_location,
               node_ids: u.elements.grep(Insn).map(&:node_id), parser: :prism }
      body = []
      last = nil
      u.elements.each do |e|
        if e.is_a?(Label)
          body << :"label_#{e.pos}" if e.refs > 0
          next
        end
        if e.line != last
          body << e.line
          last = e.line
        end
        EVENT_DISASM.each { |ev, _| body << EVENT_TO_A[ev] if e.events.include?(ev) && EVENT_TO_A[ev] }
        body << [e.name, *e.ops.map { |o| operand_to_a(o) }]
      end
      params = {}
      params[:lead_num] = u.params[:lead_num] if u.params[:lead_num] > 0
      params[:ambiguous_param0] = true if u.params[:ambiguous_param0]
      ["YARVInstructionSequence/SimpleDataFormat", 4, 0, 1, misc, u.label, u.path, u.abs_path || u.path,
       u.first_lineno, u.type, u.locals, params, [], body]
    end

    def operand_to_a(o)
      case o
      when CallData then { mid: o.mid, flag: o.flag, orig_argc: o.argc }
      when Label then :"label_#{o.pos}"
      when LocalOp then o.idx
      when Unit then to_a(o)
      else o
      end
    end

    # -- disasm --------------------------------------------------------------
    INSN_NAME_WIDTH = 38

    def disasm(u)
      out = +""
      # (iseq.c pads a short header with '=' -- by a memset past the
      #  string's end, which never shows: the header is printed as is)
      out << "== disasm: #{inspect_unit(u)}" << "\n"
      unless u.locals.empty?
        out << format("local table (size: %d, argc: %d [opts: 0, rest: -1, post: 0, block: -1, kw: -1@-1, kwrest: -1])\n",
                      u.locals.size, u.params[:lead_num])
        line = +""
        n = u.locals.size
        u.locals.each_with_index do |name, li|
          i = n - li - 1
          entry = format("[%2d] ", i + 1)
          width = line.size + entry.size + 11
          line << entry << "#{name}@#{li}"
          if li < u.params[:lead_num]
            line << (u.params[:ambiguous_param0] ? "<AmbiguousArg>" : "<Arg>")
          end
          pad = width - line.size
          line << " " * pad if pad > 0
        end
        out << line.rstrip << "\n"
      end
      pos = 0
      prev_line = 0
      u.elements.each do |e|
        next if e.is_a?(Label)
        s = format("%04d %-*s ", pos, INSN_NAME_WIDTH, e.name)
        s << e.ops.map { |o| operand_disasm(o) }.join(", ")
        if e.line && e.line != prev_line
          slen = s.size > 70 ? 0 : 70 - s.size
          s << " " * slen << format("(%4d)", e.line)
        end
        prev_line = e.line
        ev = e.events
        unless ev.empty?
          s << "[" << EVENT_DISASM.select { |k, _| ev.include?(k) }.map(&:last).join << "]"
        end
        out << s.rstrip << "\n"
        pos += 1 + e.ops.size
      end
      u.children.each { |c| out << "\n" << disasm(c) }
      out
    end

    def inspect_unit(u)
      cl = u.code_location
      "#<ISeq:#{u.label}@#{u.path}:#{u.first_lineno} (#{cl[0]},#{cl[1]})-(#{cl[2]},#{cl[3]})>"
    end

    def operand_disasm(o)
      case o
      when CallData
        flags = CALL_FLAG_NAMES.select { |b, _| o.flag & b != 0 }.map(&:last)
        "<calldata!mid:#{o.mid}, argc:#{o.argc}#{flags.empty? ? "" : ", " + flags.join("|")}>"
      when Label then o.pos.to_s
      when LocalOp then "#{o.name}@#{o.index}"
      when Unit then o.label
      when Symbol then o.inspect
      when nil then "nil"
      else o.inspect
      end
    end
  end
end
