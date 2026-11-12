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

    Label = Struct.new(:id, :pos, :refs, :sp, :unremovable)
    Insn = Struct.new(:name, :ops, :line, :node_id, :events)
    Trace = Struct.new(:event)
    # (restore: an ADJUST_RESTORE, which only sets the depth; one that is not
    #  lowers the stack to its label's -- `pop` / `adjuststack` -- at layout)
    Adjust = Struct.new(:label, :line, :node_id, :restore)
    IVC = Struct.new(:index)
    IC = Struct.new(:index, :segments)
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

      def new_label = Label.new(@labels += 1, nil, 0, nil, false)
      def emit_label(l) = @elements << l
      # (a trace event is an element of its own, as in compile.c: it goes to
      #  the instruction that follows it when the sequence is laid out, and
      #  goes away with an unreachable chunk)
      def event(e) = @elements << Trace.new(e)
      def adjust(l, restore = true) = @elements << Adjust.new(l, @line, @node, restore)
      def next_is = (@is_n = (@is_n || -1) + 1)
      def next_ic = (@ic_n = (@ic_n || -1) + 1)
      def at(line, node_id) = (@line, @node = line, node_id)
      def line = @line

      def insn(name, *ops)
        ops.each { |o| o.refs += 1 if o.is_a?(Label) }
        i = Insn.new(name, ops, @line, @node, [])
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
        u.insn(:putobject, static_value(n)) unless popped
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
      when Prism::InstanceVariableReadNode
        u.insn(:getinstancevariable, n.name, IVC.new(u.next_is)) unless popped
      when Prism::InstanceVariableWriteNode
        node(u, n.value, false)
        here(u, n)
        u.insn(:dup) unless popped
        u.insn(:setinstancevariable, n.name, IVC.new(u.next_is))
      when Prism::GlobalVariableReadNode
        u.insn(:getglobal, n.name)
        u.insn(:pop) if popped
      when Prism::GlobalVariableWriteNode
        node(u, n.value, false)
        here(u, n)
        u.insn(:dup) unless popped
        u.insn(:setglobal, n.name)
      when Prism::ConstantWriteNode
        node(u, n.value, false)
        here(u, n)
        u.insn(:dup) unless popped
        u.insn(:putspecialobject, 3)
        u.insn(:setconstant, n.name)
      when Prism::ConstantReadNode, Prism::ConstantPathNode
        segs = constant_path(n)
        raise NotImplementedError, "RubyVM::InstructionSequence: a constant path through a value is not compiled yet" unless segs
        u.insn(:opt_getconstant_path, IC.new(u.next_ic, segs))
        u.insn(:pop) if popped
      when Prism::InterpolatedStringNode then dstr(u, n, popped)
      when Prism::HashNode then hash_node(u, n, popped)
      when Prism::RangeNode then range_node(u, n, popped)
      when Prism::AndNode, Prism::OrNode then logical(u, n, popped)
      when Prism::ReturnNode then return_node(u, n, popped)
      when Prism::YieldNode then yield_node(u, n, popped)
      when Prism::ClassNode, Prism::ModuleNode then class_node(u, n, popped)
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
      when Prism::SymbolNode then n.unescaped.to_sym
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
        child.at(child.line, 0)
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

    # a constant path made of names alone -- `X`, `A::B`, `::C` -- is one
    # opt_getconstant_path over its segments
    def constant_path(n)
      case n
      when Prism::ConstantReadNode then [n.name]
      when Prism::ConstantPathNode
        if n.parent.nil? then [:"", n.name]
        else (p = constant_path(n.parent)) && p + [n.name]
        end
      end
    end

    # pm_interpolated_node_compile: adjacent literal pieces are one, the
    # first at the string's own place, a later one at its part's end
    def dstr(u, n, popped)
      count = 0
      cur = nil
      cur_at = [n.location.start_line, n.node_id]
      flush = lambda do
        next unless cur
        u.at(*cur_at)
        u.insn(:putobject, cur.freeze)
        count += 1
        cur = nil
      end
      n.parts.each_with_index do |part, i|
        case part
        when Prism::StringNode
          if cur
            cur << part.unescaped
          else
            cur = part.unescaped.dup
            cur_at = [part.location.end_line, part.node_id] if i != 0
          end
        when Prism::EmbeddedStatementsNode
          if part.statements.nil? || part.statements.body.empty?
            raise NotImplementedError, "RubyVM::InstructionSequence: an empty interpolation is not compiled yet"
          end
          flush.call
          node(u, part.statements, false)
          here(u, part)
          u.insn(:dup)
          u.insn(:objtostring, CallData.new(:to_s, CALL_FCALL | CALL_ARGS_SIMPLE, 0, nil))
          u.insn(:anytostring)
          count += 1
        else
          raise NotImplementedError, "RubyVM::InstructionSequence: #{part.type} in a string is not compiled yet"
        end
      end
      flush.call
      here(u, n)
      u.insn(:concatstrings, count)
      u.insn(:pop) if popped
    end

    def static_hash?(n)
      n.elements.all? { |e| e.is_a?(Prism::AssocNode) && static_literal?(e.key) && static_literal?(e.value) }
    end

    def hash_node(u, n, popped)
      if n.elements.empty?
        u.insn(:newhash, 0) unless popped
      elsif static_hash?(n)
        h = {}
        n.elements.each { |e| h[static_value(e.key)] = static_value(e.value) }
        u.insn(:duphash, h.freeze) unless popped
      else
        n.elements.each do |e|
          raise NotImplementedError, "RubyVM::InstructionSequence: ** in a hash is not compiled yet" unless e.is_a?(Prism::AssocNode)
          node(u, e.key, false)
          node(u, e.value, false)
        end
        here(u, n)
        u.insn(:newhash, n.elements.size * 2)
        u.insn(:pop) if popped
      end
    end

    def range_node(u, n, popped)
      excl = n.exclude_end?
      lo, hi = n.left, n.right
      if (lo.nil? || lo.is_a?(Prism::IntegerNode)) && (hi.nil? || hi.is_a?(Prism::IntegerNode))
        u.insn(:putobject, Range.new(lo&.value, hi&.value, excl)) unless popped
      else
        if lo then node(u, lo, false) else u.insn(:putnil) end
        if hi then node(u, hi, false) else u.insn(:putnil) end
        here(u, n)
        u.insn(:newrange, excl ? 1 : 0)
        u.insn(:pop) if popped
      end
    end

    def logical(u, n, popped)
      l_end = u.new_label
      node(u, n.left, false)
      here(u, n)
      u.insn(:dup) unless popped
      u.insn(n.is_a?(Prism::AndNode) ? :branchunless : :branchif, l_end)
      u.insn(:pop) unless popped
      node(u, n.right, popped)
      u.emit_label(l_end)
    end

    # pm_compile_return_node, in a method: leave, with an ADJUST before (the
    # stack down to the method's) and an ADJUST_RESTORE after
    def return_node(u, n, popped)
      scope = u
      raise NotImplementedError, "RubyVM::InstructionSequence: return from a block is not compiled yet" if scope.type == :block
      sp_l = u.new_label
      u.emit_label(sp_l)
      u.adjust(nil, false)
      args = n.arguments&.arguments || []
      raise NotImplementedError, "RubyVM::InstructionSequence: return with values is not compiled yet" if args.size > 1
      if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
      here(u, n)
      u.event(:return)
      u.insn(:leave)
      u.adjust(sp_l, true)
      u.insn(:putnil) unless popped
    end

    def yield_node(u, n, popped)
      m = u
      m = m.parent while m.type == :block
      m.params[:use_block] = true if m.type == :method
      args = n.arguments&.arguments || []
      args.each { |a| node(u, a, false) }
      here(u, n)
      u.insn(:invokeblock, CallData.new(nil, CALL_ARGS_SIMPLE, args.size, nil))
      u.insn(:pop) if popped
    end

    def class_node(u, n, popped)
      mod = n.is_a?(Prism::ModuleNode)
      name = n.constant_path.is_a?(Prism::ConstantReadNode) ? n.constant_path.name : n.constant_path.name
      l = n.location
      child = Unit.new(:class, "<#{mod ? "module" : "class"}:#{name}>", u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      u.children << child
      child.at(l.start_line, n.node_id)
      child.event(:class)
      # (an empty body's putnil is synthetic: node 0)
      if n.body then node(child, n.body, false) else (child.at(l.start_line, 0); child.insn(:putnil)) end
      child.event(:end)
      child.last_line = l.end_line
      child.at(child.last_line, n.node_id)
      child.insn(:leave)
      finish(child)
      flags = mod ? 2 : 0
      if n.constant_path.is_a?(Prism::ConstantPathNode)
        flags |= 8
        if n.constant_path.parent then node(u, n.constant_path.parent, false) else (here(u, n); u.insn(:putobject, Object)) end
      else
        here(u, n)
        u.insn(:putspecialobject, 3)
      end
      if !mod && n.superclass
        flags |= 16
        node(u, n.superclass, false)
      else
        here(u, n)
        u.insn(:putnil)
      end
      here(u, n)
      u.insn(:defineclass, name, child, flags)
      u.insn(:pop) if popped
    end

    # prism_compile.c's pm_compile_conditional: the condition jumps to the
    # then- or else-label, each part runs if a jump reaches it, and the
    # peephole optimiser (finish) tidies the jumps up as compile.c's does
    def branch(u, n, popped)
      unless_ = n.is_a?(Prism::UnlessNode)
      if unless_
        then_body = n.else_clause
        else_body = n.statements
      else
        then_body = n.statements
        else_body = n.subsequent
      end
      then_l = u.new_label
      else_l = u.new_label
      end_l = nil
      branch_condition(u, n.predicate, then_l, else_l)
      if then_l.refs > 0
        u.emit_label(then_l)
        compile_part(u, then_body, popped, n)
        if else_l.refs > 0
          end_l = u.new_label
          here(u, n)
          u.insn(:jump, end_l)
          u.insn(:pop) unless popped
        end
      end
      if else_l.refs > 0
        u.emit_label(else_l)
        compile_part(u, else_body, popped, n)
      end
      u.emit_label(end_l) if end_l
    end

    def compile_part(u, part, popped, owner)
      part = part.statements if part.is_a?(Prism::ElseNode)
      if part
        node(u, part, popped)
      elsif !popped
        here(u, owner)
        u.insn(:putnil)
      end
    end

    # pm_compile_branch_condition
    def branch_condition(u, cond, then_l, else_l)
      case cond
      when Prism::FalseNode, Prism::NilNode
        here(u, cond)
        u.insn(:jump, else_l)
        return
      when Prism::FloatNode, Prism::ImaginaryNode, Prism::IntegerNode, Prism::RationalNode,
           Prism::StringNode, Prism::SymbolNode, Prism::TrueNode
        here(u, cond)
        u.insn(:jump, then_l)
        return
      when Prism::AndNode, Prism::OrNode
        raise NotImplementedError, "RubyVM::InstructionSequence: && / || in a condition is not compiled yet"
      end
      start = u.elements.size
      node(u, cond, false)
      chunk = u.elements[start..].grep(Insn)
      if chunk.size == 1 && chunk[0].name == :putobject
        u.elements.delete(chunk[0])
        here(u, cond)
        u.insn(:jump, chunk[0].ops[0] ? then_l : else_l)
        return
      end
      here(u, cond)
      u.insn(:branchunless, else_l)
      u.insn(:jump, then_l)
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
      adjust_l = u.new_label
      next_catch_l = u.new_label
      # (the catch table's break / next / redo entries mark these: no jump
      #  reaches the adjust block a `next` lands in, and it stays)
      [redo_l, break_l, next_catch_l].each { |x| x.unremovable = true }
      u.insn(:jump, next_l)
      u.emit_label(adjust_l)
      u.insn(:putnil)
      u.emit_label(next_catch_l)
      u.insn(:pop)
      u.insn(:jump, next_l)
      u.emit_label(redo_l)
      u.loops.push([next_l, break_l, redo_l])
      node(u, n.statements, true) if n.statements
      u.loops.pop
      u.emit_label(next_l)
      if until_ then branch_condition(u, n.predicate, end_l, redo_l)
      else branch_condition(u, n.predicate, redo_l, end_l)
      end
      u.emit_label(end_l)
      u.adjust(adjust_l)
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
      u.insn(:jump, lp[1])
    end

    # -- the backend (compile.c's iseq_setup): peephole and specialised
    # instructions, operand unification, the stack depth, the layout ----
    def finish(u)
      peephole(u)
      specialize(u)
      unify(u)
      attach_traces(u)
      u.stack_max = stack_max(u)
      pos = 0
      u.elements.each do |e|
        if e.is_a?(Label) then e.pos = pos
        elsif e.is_a?(Insn) then pos += 1 + e.ops.size
        end
      end
    end

    def insn_at(els, i)
      i += 1 while i < els.size && !(els[i].is_a?(Insn) || els[i].is_a?(Adjust))
      i < els.size ? i : nil
    end

    def dest_index(els, label) = insn_at(els, els.index { |x| x.equal?(label) } + 1)

    def unref(e) = e.ops.each { |o| o.refs -= 1 if o.is_a?(Label) }

    # compile.c's iseq_peephole_optimize, the rules about jumps, branches and
    # unreachable code (more as the compiler meets them)
    def peephole(u)
      els = u.elements
      i = 0
      while i < els.size
        e = els[i]
        if e.is_a?(Insn)
          changed = peephole_insn(els, i)
          next if changed == :again
        end
        i += 1
      end
    end

    def peephole_insn(els, i)
      e = els[i]
      case e.name
      when :jump
        d = dest_index(els, e.ops[0])
        nx = insn_at(els, i + 1)
        if d && d == nx
          unref(e)
          els.delete_at(i)
          return :again
        end
        de = d && els[d]
        if de.is_a?(Insn) && de.name == :jump && !de.ops[0].equal?(e.ops[0]) && traces_before(els, d).empty?
          e.ops[0].refs -= 1
          e.ops[0] = de.ops[0]
          e.ops[0].refs += 1
          remove_unreachable(els, i + 1)
          return :again
        elsif de.is_a?(Insn) && de.name == :leave
          unref(e)
          e.name = :leave
          e.ops = []
          e.line, e.node_id = de.line, de.node_id
          return :again
        end
        pi = prev_insn(els, i)
        if pi && els[pi].is_a?(Insn) && (els[pi].name == :branchif || els[pi].name == :branchunless)
          pe = els[pi]
          pd = dest_index(els, pe.ops[0])
          if nx && pd == nx
            lbl_after = els[pi + 1].is_a?(Label) ? els[pi + 1] : nil
            refcnt = lbl_after ? lbl_after.refs : 0
            pe.name = pe.name == :branchif ? :branchunless : :branchif
            pe.ops[0].refs -= 1
            pe.ops[0] = e.ops[0]
            e.ops[0].refs += 1
            if refcnt <= 1
              unref(e)
              els.delete_at(i)
            end
            return nil
          end
        end
        return :again if remove_unreachable(els, i + 1)
      when :leave
        remove_unreachable(els, i + 1)
      end
      nil
    end

    def prev_insn(els, i)
      i -= 1
      i -= 1 while i >= 0 && !(els[i].is_a?(Insn) || els[i].is_a?(Adjust))
      i >= 0 ? i : nil
    end

    def traces_before(els, d)
      out = []
      j = d - 1
      while j >= 0 && (els[j].is_a?(Trace) || els[j].is_a?(Label))
        out << els[j] if els[j].is_a?(Trace)
        j -= 1
      end
      out
    end

    # compile.c's remove_unreachable_chunk: from first, up to a label some
    # jump from outside still reaches
    def remove_unreachable(els, first)
      return false if first >= els.size
      counts = Hash.new(0)
      last = nil
      pending = nil
      pending_end = nil
      j = first
      while j < els.size
        x = els[j]
        if x.is_a?(Insn)
          if x.name == :leave
            break if pending
            last = j
            break
          end
          x.ops.each do |o|
            next unless o.is_a?(Label)
            counts[o] += 1
            pending = nil if o.equal?(pending) && o.refs <= counts[o]
          end
        elsif x.is_a?(Label)
          if x.unremovable
            break if pending
            return false
          end
          if x.refs > counts[x]
            break if pending
            pending = x
            pending_end = (j == first) ? nil : last
          end
          j += 1
          next
        elsif x.is_a?(Adjust)
          break if pending
          return false
        end
        last = j unless pending
        j += 1
      end
      if pending
        return false unless pending_end
        last = pending_end
      end
      return false unless last
      removed = false
      (last).downto(first) do |k|
        x = els[k]
        next if x.is_a?(Label)
        unref(x) if x.is_a?(Insn)
        els.delete_at(k)
        removed = true
      end
      removed
    end

    # a send with no block and plain arguments is opt_send_without_block,
    # or one of the opt_* the VM answers for the builtin classes
    def specialize(u)
      u.elements.each do |e|
        next unless e.is_a?(Insn) && e.name == :send && e.ops[1].nil?
        cd = e.ops[0]
        if cd.flag & (CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KWARG | CALL_KW_SPLAT) == 0 &&
           cd.flag & CALL_ARGS_SIMPLE != 0 && cd.flag & CALL_FCALL == 0
          sp = case cd.argc
               when 0 then SPECIAL0[cd.mid]
               when 1 then SPECIAL1[cd.mid]
               when 2 then SPECIAL2[cd.mid]
               end
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
    end

    # operand unification (defs/opt_operand.def)
    def unify(u)
      u.elements.each do |e|
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
    end

    # (each trace's event goes to the instruction after it)
    def attach_traces(u)
      pend = []
      kept = []
      u.elements.each do |e|
        case e
        when Trace then pend << e.event
        when Insn
          e.events = (pend + e.events).uniq
          pend = []
          kept << e
        else kept << e
        end
      end
      u.elements.replace(kept)
    end

    # compile.c's fix_sp_depth: a label's depth is the first jump's to it,
    # an adjust goes back to its label's
    def stack_max(u)
      sp = max = 0
      lowered = []
      u.elements.each do |e|
        case e
        when Label
          if e.sp.nil? then e.sp = sp else sp = e.sp end
        when Adjust
          to = e.label ? (e.label.sp || 0) : 0
          if !e.restore && sp - to > 0
            lowered << [e, Insn.new(sp - to == 1 ? :pop : :adjuststack, sp - to == 1 ? [] : [sp - to], e.line, e.node_id, [])]
          end
          sp = to
        when Insn
          pop, push = stack_effect(e)
          sp = sp - pop + push
          max = sp if sp > max
          e.ops.each { |o| o.sp = sp if o.is_a?(Label) && o.sp.nil? }
        end
      end
      lowered.each { |a, i| u.elements[u.elements.index { |x| x.equal?(a) }] = i }
      u.elements.reject! { |x| x.is_a?(Adjust) }
      max
    end

    def stack_effect(e)
      case e.name
      when :putnil, :putself, :putobject, :putchilledstring, :putstring, :duparray,
           :getlocal, :getlocal_WC_0, :getlocal_WC_1, :putobject_INT2FIX_0_, :putobject_INT2FIX_1_
        [0, 1]
      when :setlocal, :setlocal_WC_0, :setlocal_WC_1, :pop, :branchif, :branchunless, :leave then [1, 0]
      when :dup then [1, 2]
      when :newarray then [e.ops[0], 1]
      when :opt_send_without_block, :send then [e.ops[0].argc + 1, 1]
      when :definemethod, :jump then [0, 0]
      when :getinstancevariable, :getglobal, :opt_getconstant_path, :putspecialobject, :duphash, :invokeblock_dummy then [0, 1]
      when :setinstancevariable, :setglobal then [1, 0]
      when :setconstant then [2, 0]
      when :objtostring, :anytostring then [e.name == :anytostring ? 2 : 1, 1]
      when :concatstrings, :newhash then [e.ops[0], 1]
      when :newrange then [2, 1]
      when :invokeblock then [e.ops[0].argc, 1]
      when :defineclass then [2, 1]
      when :adjuststack then [e.ops[0], 0]
      else
        e.name.to_s.start_with?("opt_") ? [e.ops[0].argc + 1, 1] : [0, 0]
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
        next unless e.is_a?(Insn)
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
      params[:use_block] = true if u.params[:use_block]
      ["YARVInstructionSequence/SimpleDataFormat", 4, 0, 1, misc, u.label, u.path, u.abs_path || u.path,
       u.first_lineno, u.type, u.locals, params, [], body]
    end

    def operand_to_a(o)
      case o
      when CallData then { mid: o.mid, flag: o.flag, orig_argc: o.argc }
      when Label then :"label_#{o.pos}"
      when LocalOp then o.idx
      when IVC then o.index
      when IC then o.segments
      when Unit then to_a(o)
      else o
      end
    end

    # -- trace_points: iseq.c's push_event_info order ----------------------
    def trace_points(u)
      out = []
      u.elements.each do |e|
        next unless e.is_a?(Insn) && !e.events.empty?
        ev = e.events
        out << [u.first_lineno, :class] if ev.include?(:class)
        out << [u.first_lineno, :call] if ev.include?(:call)
        out << [u.first_lineno, :b_call] if ev.include?(:b_call)
        out << [e.line, :line] if ev.include?(:line)
        out << [e.line, :end] if ev.include?(:end)
        out << [e.line, :return] if ev.include?(:return)
        out << [e.line, :b_return] if ev.include?(:b_return)
      end
      out
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
        next unless e.is_a?(Insn)
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
        "<calldata!#{o.mid ? "mid:#{o.mid}, " : ""}argc:#{o.argc}#{flags.empty? ? "" : ", " + flags.join("|")}>"
      when IVC then "<is:#{o.index}>"
      when IC then "<ic:#{o.index} #{o.segments.join("::")}>"
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
