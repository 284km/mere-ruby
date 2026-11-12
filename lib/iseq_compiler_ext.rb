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
    CALL_TAILCALL = 128
    CALL_SUPER = 256
    CALL_ZSUPER = 512
    CALL_KW_SPLAT_MUT = 2048
    CALL_ARGS_SPLAT_MUT = 4096
    CALL_FORWARDING = 8192
    # (iseq.c's order, not the bits')
    CALL_FLAG_NAMES = [[CALL_ARGS_SPLAT, "ARGS_SPLAT"], [CALL_ARGS_SPLAT_MUT, "ARGS_SPLAT_MUT"],
                       [CALL_ARGS_BLOCKARG, "ARGS_BLOCKARG"], [CALL_FCALL, "FCALL"], [CALL_VCALL, "VCALL"],
                       [CALL_ARGS_SIMPLE, "ARGS_SIMPLE"], [CALL_TAILCALL, "TAILCALL"], [CALL_SUPER, "SUPER"],
                       [CALL_ZSUPER, "ZSUPER"], [CALL_KWARG, "KWARG"], [CALL_KW_SPLAT, "KW_SPLAT"],
                       [CALL_KW_SPLAT_MUT, "KW_SPLAT_MUT"], [CALL_FORWARDING, "FORWARDING"]].freeze

    EVENT_BITS = { line: 0x01, class: 0x02, end: 0x04, call: 0x08, return: 0x10,
                   c_call: 0x20, c_return: 0x40, b_call: 0x100, b_return: 0x200, rescue: 0x4000 }.freeze
    EVENT_TO_A = { line: :RUBY_EVENT_LINE, class: :RUBY_EVENT_CLASS, end: :RUBY_EVENT_END,
                   call: :RUBY_EVENT_CALL, return: :RUBY_EVENT_RETURN,
                   b_call: :RUBY_EVENT_B_CALL, b_return: :RUBY_EVENT_B_RETURN, rescue: :RUBY_EVENT_RESCUE }.freeze
    EVENT_DISASM = [[:line, "Li"], [:class, "Cl"], [:end, "En"], [:call, "Ca"], [:return, "Re"],
                    [:c_call, "Cc"], [:c_return, "Cr"], [:b_call, "Bc"], [:b_return, "Br"], [:rescue, "Rs"]].freeze

    # opt_* that a simple send with this many arguments becomes
    # (compile.c's iseq_specialized_instruction)
    SPECIAL0 = { length: :opt_length, size: :opt_size, empty?: :opt_empty_p, nil?: :opt_nil_p,
                 succ: :opt_succ, "!": :opt_not }.freeze
    SPECIAL1 = { "+": :opt_plus, "-": :opt_minus, "*": :opt_mult, "/": :opt_div, "%": :opt_mod,
                 "==": :opt_eq, "!=": :opt_neq, "=~": :opt_regexpmatch2, "<": :opt_lt, "<=": :opt_le,
                 ">": :opt_gt, ">=": :opt_ge, "<<": :opt_ltlt, "[]": :opt_aref, "&": :opt_and,
                 "|": :opt_or }.freeze
    SPECIAL2 = { "[]=": :opt_aset }.freeze
    # (opt_newarray_send's second operand: what the array is asked --
    #  vm_core.h's VM_OPT_NEWARRAY_SEND_*)
    NEWARRAY_SEND = { max: 1, min: 2, hash: 3 }.freeze
    NEWARRAY_SEND_PACK = 4
    NEWARRAY_SEND_PACK_BUFFER = 5
    NEWARRAY_SEND_INCLUDE_P = 6

    Label = Struct.new(:id, :pos, :refs, :sp, :unremovable)
    Insn = Struct.new(:name, :ops, :line, :node_id, :events)
    Trace = Struct.new(:event)
    # (restore: an ADJUST_RESTORE, which only sets the depth; one that is not
    #  lowers the stack to its label's -- `pop` / `adjuststack` -- at layout)
    Adjust = Struct.new(:label, :line, :node_id, :restore)
    IVC = Struct.new(:index)
    # (is_entries holds the ivar caches first and the constant caches after
    #  them: an IC's place there, which disasm shows, is past every IVC)
    IC = Struct.new(:index, :segments, :base)
    CallData = Struct.new(:mid, :flag, :argc, :kwargs)
    # (defined's first operand: a number in to_a, a name in disasm)
    DefType = Struct.new(:n)
    DEFINED = { nil: 1, ivar: 2, lvar: 3, gvar: 4, cvar: 5, const: 6, method: 7, yield: 8, zsuper: 9,
                self: 10, true: 11, false: 12, asgn: 13, expr: 14, ref: 15, func: 16, const_from: 17 }.freeze
    DEFINED_NAMES = [nil, "nil", "instance-variable", "local-variable", "global-variable", "class variable",
                     "constant", "method", "yield", "super", "self", "true", "false", "assignment",
                     "expression", "ref", "func", "constant-from"].freeze
    # (opt_case_dispatch's hash: the first `when` of a key wins; its labels
    #  are not counted as references, as compile.c's TS_CDHASH is not)
    CDHash = Struct.new(:entries)

    # rb_compile_option_t's defaults (the ones ISeq.compile_option shows)
    DEFAULT_OPTIONS = { inline_const_cache: true, peephole_optimization: true, tailcall_optimization: false,
                        specialized_instruction: true, operands_unification: true,
                        instructions_unification: false, frozen_string_literal: false }.freeze

    THROUGH = %i[block rescue ensure].freeze

    # one instruction sequence being built, and what to_a / disasm read off it
    class Unit
      attr_reader :type, :label, :path, :abs_path, :first_lineno, :locals, :params,
                  :children, :elements, :code_location, :node_id, :parent
      attr_accessor :stack_max
      attr_writer :opts, :parser
      def parser = (@parser || :prism)
      # (the catch table: [type, start, end, iseq, cont] as ADD_CATCH_ENTRY
      #  pushes them; it is kept only when the sequence may catch something
      #  -- catch_except_p)
      attr_reader :catch
      attr_accessor :catch_except, :block_labels, :block_nop

      def add_catch(type, ls, le, iseq, lc)
        ls.unremovable = true
        ls.refs += 1
        le.refs += 1
        lc.refs += 1 if lc
        (@catch ||= []) << [type, ls, le, iseq, lc]
      end

      # set_catch_except_p: this sequence and every one around it, up to
      # one made with NEW_ISEQ -- a method, a singleton class -- which has
      # no parent_iseq
      attr_accessor :detached
      def set_catch_except
        @catch_except = true
        @parent&.set_catch_except unless @detached
      end

      def kept_catch = (@catch_except && @catch) || []
      def opts = (@opts ||= @parent ? @parent.opts : DEFAULT_OPTIONS)

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
      # (prism_compile.c's DECL_ANCHOR: instructions built aside, laid out
      #  later in another order)
      def capture
        saved = @elements
        @elements = []
        yield
        @elements
      ensure
        @elements = saved
      end
      def append(seq) = @elements.concat(seq)
      # (a trace event is an element of its own, as in compile.c: it goes to
      #  the instruction that follows it when the sequence is laid out, and
      #  goes away with an unreachable chunk)
      def event(e) = @elements << Trace.new(e)
      # (new_adjust_body: its label is unremovable and referenced)
      def adjust(l, restore = true)
        if l
          l.unremovable = true
          l.refs += 1
        end
        @elements << Adjust.new(l, @line, @node, restore)
      end
      def next_is = (@is_n = (@is_n || -1) + 1)
      def next_ic = (@ic_n = (@ic_n || -1) + 1)
      def ivc_size = (@is_n || -1) + 1
      def at(line, node_id) = (@line, @node = line, node_id)
      def line = @line

      def insn(name, *ops)
        name = local_insn_name(name, ops)
        ops.each { |o| o.refs += 1 if o.is_a?(Label) }
        i = Insn.new(name, ops, @line, @node, [])
        @elements << i
        i
      end

      # (iseq_add_getlocal / iseq_add_setlocal: the block parameter of a
      #  method -- a sequence that is its own local_iseq -- is read with
      #  getblockparam and written with setblockparam)
      def local_insn_name(name, ops)
        return name unless (name == :getlocal || name == :setlocal) && ops[0].is_a?(LocalOp)
        o = self
        ops[1].times { o = o.parent }
        return name if THROUGH.include?(o.type) || o.params[:block_start] != ops[0].index
        name == :getlocal ? :getblockparam : :setblockparam
      end

      # (a block, rescue or ensure sequence reads its locals through to the
      #  sequence around it; the method, class or top one is its local_iseq)
      def local_iseq
        u = self
        u = u.parent while THROUGH.include?(u.type)
        u
      end

      # make_name_for_block's count: the blocks from here out to local_iseq
      def blocks_out
        d, u = 0, self
        while THROUGH.include?(u.type)
          d += 1 if u.type == :block
          u = u.parent
        end
        d
      end

      # ensure regions being compiled (pm_add_ensure_iseq's stack; a loop
      # pushes a stop)
      def ensures = (@ensures ||= [])

      # (the index_lookup_table: a name's slot, which for a parameter given
      #  twice -- `_` -- is the one that is not repeated)
      attr_writer :lookup
      def index_of(name) = (@lookup && @lookup[name]) || @locals.index(name)

      def level_of(name)
        lv, u = 0, self
        while u
          return [lv, u] if u.locals.include?(name)
          u = THROUGH.include?(u.type) ? u.parent : nil
          lv += 1
        end
        nil
      end
    end

    module_function

    # -- entry ---------------------------------------------------------------
    def compile(src, path, abs_path, line, label = "<compiled>", opts = nil)
      opts = DEFAULT_OPTIONS.merge(opts || {})
      # (what this compiler does not do yet it refuses: a tail call, the
      #  unified instruction pairs)
      raise NotImplementedError, "RubyVM::InstructionSequence: tailcall_optimization is not compiled yet" if opts[:tailcall_optimization]
      raise NotImplementedError, "RubyVM::InstructionSequence: instructions_unification is not compiled yet" if opts[:instructions_unification]
      po = { filepath: path, line: line }
      po[:frozen_string_literal] = true if opts[:frozen_string_literal]
      result = Prism.parse(src, **po)
      raise SyntaxError, result.errors.map(&:message).join("\n") unless result.success?
      root = result.value
      l = root.location
      unit = Unit.new(:top, label, path, abs_path, line, root.locals, nil,
                      [l.start_line, l.start_column, l.end_line, l.end_column], root.node_id)
      unit.opts = opts
      compile_body(unit, root.statements, root.node_id)
      finish(unit)
      unit
    end

    # (the scope's `leave` is the scope node's, on its closing line when it
    #  has one -- a def's `end`, a block's `}` -- and the last line otherwise)
    def compile_body(unit, stmts, node_id, end_line = nil)
      # (a block's body sits between its start and end labels, which its
      #  redo / next entries and a `next` in it name)
      if unit.type == :block
        unit.block_labels = [unit.new_label, unit.new_label]
        unit.emit_label(unit.block_labels[0])
      end
      # (a body with rescue / ensure is a BeginNode)
      if stmts.nil? || (stmts.is_a?(Prism::StatementsNode) && stmts.body.empty?)
        unit.at(unit.line, node_id)
        unit.insn(:putnil)
      else
        node(unit, stmts, false)
      end
      if unit.type == :method
        unit.event(:return)
      elsif unit.type == :block
        unit.emit_label(unit.block_labels[1])
        unit.event(:b_return)
      end
      unit.last_line = end_line if end_line
      unit.at(unit.last_line || unit.line, node_id)
      unit.insn(:leave)
      if unit.type == :block
        st, en = unit.block_labels
        unit.add_catch(:redo, st, en, nil, st)
        unit.add_catch(:next, st, en, nil, en)
      end
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
      when Prism::CaseNode then case_node(u, n, popped)
      when Prism::MultiWriteNode then multi_write(u, n, popped)
      when Prism::LambdaNode
        st = n.parameters ? n.parameters.location : nil
        start = st ? [st.start_line, st.start_column] : [n.operator_loc.end_line, n.operator_loc.end_column]
        blk = block_unit(u, n, n.opening_loc.start_line, start)
        here(u, n)
        u.insn(:putspecialobject, 1)
        u.insn(:send, CallData.new(:lambda, CALL_FCALL, 0, nil), blk)
        u.insn(:pop) if popped
      when Prism::DefinedNode then defined_node(u, n, popped)
      when Prism::SuperNode, Prism::ForwardingSuperNode then super_node(u, n, popped)
      when Prism::ForNode then for_node(u, n, popped)
      when Prism::SingletonClassNode then singleton_class(u, n, popped)
      when Prism::LocalVariableOrWriteNode, Prism::LocalVariableAndWriteNode,
           Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode
        or_and_write(u, n, popped)
      when Prism::SplatNode
        node(u, n.expression, popped) if n.expression
        here(u, n)
        u.insn(:splatarray, true) unless popped
      when Prism::IfNode, Prism::UnlessNode then branch(u, n, popped)
      when Prism::WhileNode, Prism::UntilNode then loop_node(u, n, popped)
      when Prism::DefNode then define(u, n, popped)
      when Prism::BreakNode then break_node(u, n, popped)
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
      when Prism::ConstantReadNode
        constant_read(u, n.name, n.location, n)
        u.insn(:pop) if popped
      when Prism::ConstantPathNode
        if u.opts[:inline_const_cache] && (segs = constant_path(n))
          u.insn(:opt_getconstant_path, IC.new(u.next_ic, segs))
        else
          # (pm_compile_constant_path: what the path starts from -- nil
          #  when it starts from a name -- then a getconstant a segment)
          prefix = []
          body = []
          constant_path_split(u, n, prefix, body)
          here(u, n)
          if prefix.empty? then u.insn(:putnil) else u.append(prefix) end
          u.append(body)
        end
        here(u, n)
        u.insn(:pop) if popped
      when Prism::InterpolatedStringNode then dstr(u, n, popped)
      when Prism::HashNode then hash_node(u, n, popped)
      when Prism::RangeNode then range_node(u, n, popped)
      when Prism::AndNode, Prism::OrNode then logical(u, n, popped)
      when Prism::ReturnNode then return_node(u, n, popped)
      when Prism::YieldNode then yield_node(u, n, popped)
      when Prism::ClassNode, Prism::ModuleNode then class_node(u, n, popped)
      when Prism::SourceFileNode
        u.insn(:putchilledstring, u.path.dup.freeze) unless popped
      when Prism::SourceLineNode
        u.insn(:putobject, n.location.start_line) unless popped
      when Prism::RegularExpressionNode
        u.insn(:putobject, Regexp.new(n.unescaped, n.options & 7)) unless popped
      when Prism::BeginNode
        if n.ensure_clause then ensure_part(u, n, popped)
        elsif n.rescue_clause then rescue_part(u, n, popped)
        elsif n.statements then node(u, n.statements, popped)
        elsif !popped then synthetic_putnil(u)
        end
      when Prism::RescueNode then rescue_clause(u, n)
      when Prism::EnsureNode then node(u, n.statements, popped) if n.statements
      when Prism::RescueModifierNode then rescue_modifier(u, n, popped)
      when Prism::RetryNode
        raise NotImplementedError, "RubyVM::InstructionSequence: retry outside a rescue clause is not compiled yet" unless u.type == :rescue
        u.insn(:putnil)
        u.insn(:throw, 4)
        u.insn(:pop) if popped
      when Prism::NextNode then next_node(u, n, popped)
      when Prism::InterpolatedSymbolNode
        dstr(u, n, false)
        here(u, n)
        u.insn(:intern)
        u.insn(:pop) if popped
      when Prism::ElseNode then compile_part(u, n, popped, nil)
      when Prism::ParenthesesNode
        if n.body then node(u, n.body, popped) else (u.insn(:putnil) unless popped) end
      when Prism::AssocNode
        node(u, n.key, popped)
        node(u, n.value, popped)
      when Prism::AssocSplatNode
        if n.value then node(u, n.value, popped)
        elsif !popped then u.insn(:getlocal, *local_ref(u, :**, nil))
        end
      when Prism::BlockArgumentNode
        # (an anonymous one is the method's &, forwarded)
        if n.expression then node(u, n.expression, popped)
        else u.insn(:getblockparamproxy, *local_ref(u, :&, nil))
        end
      when Prism::ImplicitNode then node(u, n.value, popped)
      when Prism::GlobalVariableAndWriteNode, Prism::GlobalVariableOrWriteNode,
           Prism::ConstantAndWriteNode, Prism::ConstantOrWriteNode
        var_and_or_write(u, n, popped)
      when Prism::GlobalVariableOperatorWriteNode
        u.insn(:getglobal, n.name)
        node(u, n.value, false)
        here(u, n)
        push_send(u, n.binary_operator, 1)
        u.insn(:dup) unless popped
        u.insn(:setglobal, n.name)
      when Prism::InstanceVariableOperatorWriteNode
        u.insn(:getinstancevariable, n.name, IVC.new(u.next_is))
        node(u, n.value, false)
        here(u, n)
        push_send(u, n.binary_operator, 1)
        u.insn(:dup) unless popped
        u.insn(:setinstancevariable, n.name, IVC.new(u.next_is))
      when Prism::ConstantOperatorWriteNode
        constant_read(u, n.name, n.name_loc, n)
        node(u, n.value, false)
        here(u, n)
        push_send(u, n.binary_operator, 1)
        u.insn(:dup) unless popped
        u.insn(:putspecialobject, 3)
        u.insn(:setconstant, n.name)
      when Prism::ConstantPathWriteNode, Prism::ConstantPathAndWriteNode, Prism::ConstantPathOrWriteNode,
           Prism::ConstantPathOperatorWriteNode
        constant_path_write(u, n, popped)
      when Prism::CallAndWriteNode, Prism::CallOrWriteNode then call_and_or_write(u, n, popped)
      when Prism::CallOperatorWriteNode then call_operator_write(u, n, popped)
      when Prism::IndexOperatorWriteNode, Prism::IndexAndWriteNode, Prism::IndexOrWriteNode
        index_write(u, n, popped)
      when Prism::ShareableConstantNode
        # (a `shareable_constant_value` constant: compiled only when it is
        #  X = a literal, which is pushed already made shareable)
        w = n.write
        lit = w.is_a?(Prism::ConstantWriteNode) && shareable_literal(w.value)
        unless lit
          raise NotImplementedError, "RubyVM::InstructionSequence: a shareable_constant_value write of this is not compiled yet"
        end
        here(u, w.value)
        u.insn(:putobject, lit[0])
        here(u, n)
        u.insn(:dup) unless popped
        u.insn(:putspecialobject, 3)
        u.insn(:setconstant, w.name)
      when Prism::AliasMethodNode
        # (pm_compile_alias_method_node: core#set_method_alias on the cbase)
        u.insn(:putspecialobject, 1)
        u.insn(:putspecialobject, 2)
        node(u, n.new_name, false)
        node(u, n.old_name, false)
        here(u, n)
        push_send(u, :"core#set_method_alias", 3)
        u.insn(:pop) if popped
      when Prism::AliasGlobalVariableNode
        # (the names as they are written: $a, $&, $1)
        u.insn(:putspecialobject, 1)
        u.insn(:putobject, n.new_name.location.slice.to_sym)
        u.insn(:putobject, n.old_name.location.slice.to_sym)
        push_send(u, :"core#set_variable_alias", 2)
        u.insn(:pop) if popped
      when Prism::UndefNode
        # (pm's PM_UNDEF_NODE: one core#undef_method a name, the ones but
        #  the last popped)
        n.names.each_with_index do |name, i|
          here(u, n)
          u.insn(:putspecialobject, 1)
          u.insn(:putspecialobject, 2)
          node(u, name, false)
          here(u, n)
          push_send(u, :"core#undef_method", 2)
          u.insn(:pop) if i < n.names.size - 1
        end
        u.insn(:pop) if popped
      when Prism::XStringNode
        # (`x`: self.`("x")
        u.insn(:putself)
        u.insn(:putobject, n.unescaped.dup.freeze)
        u.insn(:send, CallData.new(:`, CALL_FCALL | CALL_ARGS_SIMPLE, 1, nil), nil)
        u.insn(:pop) if popped
      when Prism::InterpolatedXStringNode
        u.insn(:putself)
        dstr(u, n, false)
        here(u, n)
        u.insn(:send, CallData.new(:`, CALL_FCALL | CALL_ARGS_SIMPLE, 1, nil), nil)
        u.insn(:pop) if popped
      else
        raise NotImplementedError, "RubyVM::InstructionSequence: #{n.type} is not compiled yet"
      end
    end

    # an instruction is the node's that emits it: after its children a node
    # marks its own place again
    def here(u, n) = u.at(n.location.start_line, n.node_id)

    # compile.c's new_callinfo: keywords are counted in argc, and a call
    # without a splat, a block argument, keywords, forwarding or a block
    # is ARGS_SIMPLE
    def ci(mid, argc, flag = 0, kws = nil, blk = false)
      flag |= CALL_KWARG if kws
      if flag & (CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KWARG | CALL_KW_SPLAT | CALL_FORWARDING) == 0 && !blk
        flag |= CALL_ARGS_SIMPLE
      end
      CallData.new(mid, flag, argc + (kws ? kws.size : 0), kws)
    end

    # (PUSH_SEND_R: a send at the current place; new_insn_send makes one
    #  that forwards `...` a sendforward)
    def push_send(u, mid, argc, flag = 0, kws = nil, blk = nil)
      u.insn(:send, ci(mid, argc, flag, kws, !blk.nil?), blk)
    end

    def sendish(u, mid, argc, flag, kws, blk)
      u.insn(flag & CALL_FORWARDING != 0 ? :sendforward : :send, ci(mid, argc, flag, kws, !blk.nil?), blk)
    end

    def local_ref(u, name, depth)
      lv, owner = u.level_of(name)
      raise NotImplementedError, "local #{name} not found" unless owner
      i = owner.index_of(name)
      [LocalOp.new(name, i, owner.locals.size - i + VM_ENV_DATA_SIZE - 1), lv]
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
      when Prism::HashNode then n.elements.to_h { |e| [static_value(e.key), static_value(e.value)] }.freeze
      when Prism::RangeNode
        Range.new(n.left && static_value(n.left), n.right && static_value(n.right), n.exclude_end?).freeze
      when Prism::RegularExpressionNode then Regexp.new(n.unescaped, n.options & 7)
      else n.value
      end
    end

    # pm_compile_array_node: a static literal is one duparray; otherwise
    # chunks of up to 0x100 elements (newarray, then pushtoarray), a splat
    # (splatarray true / concattoarray), and a run of 0x40 or more static
    # elements as one array; popped, the array is still built and popped
    MAX_NEW_ARRAY = 0x100
    MIN_TMP_ARRAY = 0x40

    def array(u, n, popped)
      if n.static_literal?
        unless popped
          here(u, n)
          if n.elements.empty? then u.insn(:newarray, 0) else u.insn(:duparray, static_value(n)) end
        end
        return
      end
      els = n.elements
      size = 0
      first = true
      static_run = false
      flush = lambda do
        if size > 0
          here(u, n)
          if first then u.insn(:newarray, size) else u.insn(:pushtoarray, size) end
          first = false
          size = 0
        end
      end
      container = ->(e) { e.is_a?(Prism::ArrayNode) || e.is_a?(Prism::HashNode) || e.is_a?(Prism::RangeNode) }
      i = 0
      while i < els.size
        e = els[i]
        if e.is_a?(Prism::SplatNode)
          flush.()
          if e.expression
            node(u, e.expression, false)
          else
            # (the method's anonymous *)
            here(u, n)
            u.insn(:getlocal, *local_ref(u, :*, nil))
          end
          here(u, n)
          if first then (u.insn(:splatarray, true); first = false) else u.insn(:concattoarray) end
          static_run = false
        elsif e.is_a?(Prism::KeywordHashNode)
          # (the last element: a hash pushed on, or -- when it is ** alone
          #  -- pushtoarraykwsplat, which pushes it only when it is not
          #  empty)
          if size == 0 && first
            here(u, n)
            u.insn(:newarray, 0)
            first = false
          else
            flush.()
          end
          hash_elements(u, e, e.elements, false)
          if e.elements.all? { |x| x.is_a?(Prism::AssocSplatNode) }
            here(u, n)
            u.insn(:pushtoarraykwsplat)
          else
            size += 1
          end
        elsif e.static_literal? && !container.(e) && !static_run && i + MIN_TMP_ARRAY < els.size
          r = i + 1
          r += 1 while r < els.size && els[r].static_literal? && !container.(els[r])
          if r - i >= MIN_TMP_ARRAY
            tmp = els[i...r].map { |x| static_value(x) }.freeze
            i = r - 1
            flush.()
            here(u, n)
            if first then (u.insn(:duparray, tmp); first = false)
            else (u.insn(:putobject, tmp); u.insn(:concattoarray))
            end
          else
            node(u, e, false)
            size += 1
            flush.() if size >= MAX_NEW_ARRAY
            static_run = true
          end
        else
          node(u, e, false)
          size += 1
          flush.() if size >= MAX_NEW_ARRAY
          static_run = false
        end
        i += 1
      end
      flush.()
      here(u, n)
      u.insn(:pop) if popped
    end

    # pm_compile_call_node and pm_compile_call: at the method name's line;
    # a literal string's freeze / -@, an attribute write's value kept
    # under its receiver (setn), &. (branchnil), a block parameter's
    # call (getblockparamproxy), and `new` inlined (opt_new)
    # (recv_done: pm_compile_call alone, the receiver already pushed --
    #  defined?'s way with a call's receiver)
    def call(u, n, popped, recv_done = false)
      line = (n.message_loc || n.location).start_line
      at = -> { u.at(line, n.node_id) }
      # (a call with a block starts at a label a break entry may name)
      start = u.new_label
      u.emit_label(start) if n.block && !recv_done
      if !recv_done && (n.name == :-@ || n.name == :freeze) && n.receiver.is_a?(Prism::StringNode) && !n.safe_navigation? &&
         n.arguments.nil? && n.block.nil? && u.opts[:specialized_instruction]
        at.()
        u.insn(n.name == :freeze ? :opt_str_freeze : :opt_str_uminus, n.receiver.unescaped.dup.freeze,
               CallData.new(n.name, CALL_ARGS_SIMPLE, 0, nil))
        u.insn(:pop) if popped
        return
      end
      write = n.attribute_write? && !popped
      at.()
      u.insn(:putnil) if write && !recv_done
      r = n.receiver
      if recv_done
        nil
      elsif r.nil?
        at.()
        u.insn(:putself)
      elsif n.name == :call && r.is_a?(Prism::LocalVariableReadNode) && block_param?(u, r.name)
        u.at(line, r.node_id)
        u.insn(:getblockparamproxy, *local_ref(u, r.name, r.depth))
      else
        node(u, r, false)
      end
      fcall = r.nil? || n.ignore_visibility?
      else_l = end_l = nil
      if n.safe_navigation?
        else_l = u.new_label
        end_l = u.new_label
        at.()
        u.insn(:dup)
        u.insn(:branchnil, else_l)
      end
      prelude = u.elements.size
      argc, flag, kws = setup_args(u, n.arguments, n.block, [line, n.node_id])
      blk = n.block.is_a?(Prism::BlockNode) ? block_unit(u, n.block) : nil
      flag |= CALL_VCALL if blk.nil? && n.variable_call?
      flag |= CALL_FCALL if fcall
      at.()
      if write
        # (the value is the last argument: kept under the receiver, from
        #  the splatted array's end when there is a splat)
        if flag & CALL_ARGS_BLOCKARG != 0
          u.insn(:topn, 1)
          if flag & CALL_ARGS_SPLAT != 0
            u.insn(:putobject, -1)
            push_send(u, :[], 1)
          end
          u.insn(:setn, argc + 3)
          u.insn(:pop)
        elsif flag & CALL_ARGS_SPLAT != 0
          u.insn(:dup)
          u.insn(:putobject, -1)
          push_send(u, :[], 1)
          u.insn(:setn, argc + 2)
          u.insn(:pop)
        else
          u.insn(:setn, argc + 1)
        end
      end
      # (a keyword splat the callee could keep, passed with a block
      #  argument: splatkw)
      u.insn(:splatkw) if flag & CALL_KW_SPLAT != 0 && flag & CALL_ARGS_BLOCKARG != 0 && flag & CALL_KW_SPLAT_MUT == 0
      if u.opts[:specialized_instruction] && n.name == :new && n.block.nil? && flag & CALL_ARGS_BLOCKARG == 0
        pair = [Insn.new(:putnil, [], line, n.node_id, []), Insn.new(:swap, [], line, n.node_id, [])]
        if u.elements.size == prelude then u.elements.concat(pair) else u.elements.insert(prelude, *pair) end
        not_basic = u.new_label
        done = u.new_label
        fwd = flag & CALL_FORWARDING != 0 ? 1 : 0
        u.insn(:opt_new, ci(:new, argc + fwd, flag, kws), not_basic)
        sendish(u, :initialize, argc, flag | CALL_FCALL, kws, nil)
        u.insn(:jump, done)
        u.emit_label(not_basic)
        sendish(u, :new, argc, flag, kws, nil)
        u.insn(:swap)
        u.emit_label(done)
        u.insn(:pop)
      else
        sendish(u, n.name, argc, flag, kws, blk)
        # (a block that keeps a catch table may be broken out of: the
        #  break lands just past the send)
        unless blk.nil? || blk.kept_catch.empty?
          retry_end = u.new_label
          u.emit_label(retry_end)
          u.add_catch(:break, start, retry_end, blk, retry_end)
        end
      end
      if else_l
        u.insn(:jump, end_l)
        u.emit_label(else_l)
        u.emit_label(end_l)
      end
      u.insn(:pop) if write
      u.insn(:pop) if popped
    end

    # `for x in c`: c.each with a block whose one parameter is hidden and
    # written to x (a local of the scope around) before the block's b_call
    def for_node(u, n, popped)
      unless n.index.is_a?(Prism::LocalVariableTargetNode)
        raise NotImplementedError, "RubyVM::InstructionSequence: a for loop over this target is not compiled yet"
      end
      retry_l = u.new_label
      retry_end = u.new_label
      u.emit_label(retry_l)
      node(u, n.collection, false)
      method_unit = u
      method_unit = method_unit.local_iseq
      levels = block_levels(u)
      label = levels == 1 ? "block in #{method_unit.label}" : "block (#{levels} levels) in #{method_unit.label}"
      l = n.location
      hidden = 0
      child = Unit.new(:block, label, u.path, u.abs_path, l.start_line, [hidden], u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      child.params[:lead_num] = 1
      child.params[:for] = true
      u.children << child
      t = n.index
      child.at(t.location.start_line, t.node_id)
      child.insn(:getlocal, *local_ref(child, hidden, 0))
      child.insn(:setlocal, *local_ref(child, t.name, t.depth + 1))
      child.at(l.start_line, n.node_id)
      child.event(:b_call)
      child.block_nop = child.insn(:nop)
      compile_body(child, n.statements, n.node_id, l.end_line)
      finish(child)
      here(u, n)
      u.insn(:send, CallData.new(:each, 0, 0, nil), child)
      u.emit_label(retry_end)
      u.insn(:pop) if popped
      u.add_catch(:break, retry_l, retry_end, child, retry_end)
    end

    # make_name_for_block: one, and one more for each block from the scope
    # the block is in up to its method's
    def block_levels(u) = 1 + u.blocks_out

    # pm_compile_super_node / pm_compile_forwarding_super_node: invokesuper,
    # with the arguments given or -- zsuper -- the method's own parameters
    # read where they are; the break entry is pushed whether or not there
    # is a block
    def super_node(u, n, popped)
      zsuper = n.is_a?(Prism::ForwardingSuperNode)
      retry_l = u.new_label
      retry_end = u.new_label
      u.emit_label(retry_l) unless zsuper && n.block.nil?
      here(u, n)
      u.insn(:putself)
      local = u.local_iseq
      blk = nil
      if zsuper && local.params[:forwardable]
        # (pm_compile_forwarding_super_node in a forwardable method: its
        #  `...` passed on with invokesuperforward, and no break entry)
        blk = block_unit(u, n.block) if n.block
        local.params[:use_block] = true unless n.block
        here(u, n)
        u.insn(:getlocal, *local_ref(u, :"...", nil))
        u.insn(:invokesuperforward, ci(nil, 0, CALL_ZSUPER | CALL_SUPER | CALL_FCALL | CALL_FORWARDING, nil, !blk.nil?), blk)
        u.insn(:pop) if popped
        return
      end
      if zsuper
        blk = block_unit(u, n.block) if n.block
        argc, flag = zsuper_args(u, n, local)
        flag |= CALL_ZSUPER | CALL_SUPER | CALL_FCALL
        kws = nil
      else
        argc, flag, kws = setup_args(u, n.arguments, n.block, [n.location.start_line, n.node_id])
        flag |= CALL_SUPER | CALL_FCALL
        blk = block_unit(u, n.block) if n.block.is_a?(Prism::BlockNode)
      end
      local.params[:use_block] = true unless n.block
      here(u, n)
      u.insn(:splatkw) if flag & CALL_ARGS_BLOCKARG != 0 && flag & CALL_KW_SPLAT != 0 && flag & CALL_KW_SPLAT_MUT == 0
      if zsuper
        u.insn(:invokesuper, ci(nil, argc, flag, nil, !blk.nil?), blk)
      else
        # (super(...) in a forwardable method: invokesuperforward)
        fwd = n.arguments&.contains_forwarding? && local.params[:forwardable]
        flag |= CALL_FORWARDING if fwd
        u.insn(fwd ? :invokesuperforward : :invokesuper, ci(nil, argc, flag, kws, !blk.nil?), blk)
      end
      if !zsuper || n.block
        u.emit_label(retry_end)
        u.add_catch(:break, retry_l, retry_end, blk, retry_end)
      end
      u.insn(:pop) if popped
    end

    # the method's parameters as zsuper passes them on
    def zsuper_args(u, n, local)
      pr = local.params
      level = 0
      x = u
      while x != local
        level += 1
        x = x.parent
      end
      get = ->(i) { here(u, n); u.insn(:getlocal, local_op(local, i), level) }
      argc = 0
      flag = 0
      pr[:lead_num].times { |i| get.(i) }
      argc += pr[:lead_num]
      nopt = pr[:opt] ? pr[:opt].size - 1 : 0
      nopt.times { |j| get.(argc + j) }
      argc += nopt
      if pr[:rest_start]
        get.(pr[:rest_start])
        u.insn(:splatarray, false)
        argc = pr[:rest_start] + 1
        flag |= CALL_ARGS_SPLAT
      end
      if pr[:post_num]
        pr[:post_num].times { |j| get.(pr[:post_start] + j) }
        if pr[:rest_start]
          u.insn(:newarray, pr[:post_num])
          u.insn(:concatarray)
        else
          argc = pr[:post_num] + pr[:post_start]
        end
      end
      if pr[:keyword]
        argc += 1
        u.insn(:putspecialobject, 1)
        if pr[:kwrest]
          get.(pr[:kwrest])
          u.insn(:send, CallData.new(:dup, CALL_ARGS_SIMPLE, 0, nil), nil)
        else
          u.insn(:newhash, 0)
        end
        names = pr[:keyword].map { |k| k.is_a?(Array) ? k[0] : k }
        names.each do |k|
          u.insn(:putobject, k)
          get.(local.index_of(k))
        end
        u.insn(:send, CallData.new(:"core#hash_merge_ptr", CALL_ARGS_SIMPLE, names.size * 2 + 1, nil), nil)
        flag |= CALL_KW_SPLAT | CALL_KW_SPLAT_MUT
      elsif pr[:kwrest]
        get.(pr[:kwrest])
        argc += 1
        flag |= CALL_KW_SPLAT
      end
      [argc, flag]
    end

    def local_op(owner, i)
      name = owner.locals[i]
      LocalOp.new(name, i, owner.locals.size - i + VM_ENV_DATA_SIZE - 1)
    end

    def block_param?(u, name)
      _, owner = u.level_of(name)
      owner && !THROUGH.include?(owner.type) && owner.params[:block_start] && owner.locals[owner.params[:block_start]] == name
    end

    # pm_setup_args: the arguments as the call takes them (argc, the
    # flags, the keywords). A splat is `splatarray` -- one that is not last
    # copied (ARGS_SPLAT_MUT), unless a block argument or keywords that
    # cannot touch the array allow it not to be -- and what follows it
    # pushed onto it; keywords with symbol keys are KWARG, any others a
    # hash (KW_SPLAT, KW_SPLAT_MUT when it is a new one); `...` is the
    # method's *, ** and &, or its one `...` local when it is forwardable
    # (at: the line and node of what the call's instructions are at)
    SPLATARRAY_TRUE = 1
    DUP_SINGLE_KW_SPLAT = 2

    def setup_args(u, an, block, at, flag = 0)
      args = an ? an.arguments : []
      dup_rest = SPLATARRAY_TRUE
      if args.size >= 2 && an.contains_splat? && !an.contains_multiple_splats? && args.last.is_a?(Prism::KeywordHashNode)
        # (f(1, *a, k: v): no copy, unless a keyword could change the array)
        dup_rest = 0
        args.last.elements.each do |e|
          break unless dup_rest == 0
          case e
          when Prism::AssocNode then dup_rest = SPLATARRAY_TRUE if dup_rest_p(e.key) || dup_rest_p(e.value)
          when Prism::AssocSplatNode then dup_rest = SPLATARRAY_TRUE if e.value && dup_rest_p(e.value)
          end
        end
      end
      initial = dup_rest
      st = [dup_rest]
      if block.is_a?(Prism::BlockArgumentNode)
        # (the block argument is compiled first and laid out after: what it
        #  is decides whether the splat is copied)
        regular = true
        if block.expression && dup_rest_p(block.expression)
          st[0] = initial = SPLATARRAY_TRUE | DUP_SINGLE_KW_SPLAT
        end
        barg = u.capture { node(u, block, false) }
        flag |= CALL_ARGS_BLOCKARG
        if barg.size == 1 && barg[0].is_a?(Insn)
          barg[0].name = :getblockparamproxy if barg[0].name == :getblockparam
          regular = false
        end
        argc, flag, kws = setup_args_core(u, an, flag, regular, st, at)
        u.append(barg)
      else
        argc, flag, kws = setup_args_core(u, an, flag, false, st, at)
      end
      flag |= CALL_ARGS_SPLAT_MUT if flag & CALL_ARGS_SPLAT != 0 && st[0] != initial
      [argc, flag, kws]
    end

    # pm_setup_args_core (st: dup_rest, which a first splat that is not last
    # takes)
    def setup_args_core(u, an, flag, regular_blockarg, st, at)
      orig_argc = 0
      kws = nil
      # (no arguments to a call that is FCALL already -- `self[] ||= v` --
      #  makes it VCALL too)
      return [0, flag & CALL_FCALL != 0 ? flag | CALL_VCALL : flag, nil] unless an
      args = an.arguments
      has_splat = false
      has_kw_splat = an.contains_keyword_splat?
      post = 0
      args.each_with_index do |a, index|
        case a
        when Prism::KeywordHashNode
          els = a.elements
          if has_kw_splat || has_splat
            flag |= CALL_KW_SPLAT
            has_kw_splat = true
            if els.size > 1 || !(els.size == 1 && els[0].is_a?(Prism::AssocSplatNode))
              flag |= CALL_KW_SPLAT_MUT
              hash_elements(u, a, els, true)
            elsif st[0] & DUP_SINGLE_KW_SPLAT != 0
              flag |= CALL_KW_SPLAT_MUT
              u.at(*at)
              u.insn(:putspecialobject, 1)
              u.insn(:newhash, 0)
              hash_elements(u, a, els, true)
              u.at(*at)
              push_send(u, :"core#hash_merge_kwd", 2)
            else
              hash_elements(u, a, els, true)
            end
          elsif a.symbol_keys?
            # (a keyword given twice: the last one counts, the earlier
            #  values are compiled popped)
            last = {}
            els.each_with_index { |e, i| last[e.key.unescaped.to_sym] = i }
            kws = []
            els.each_with_index do |e, i|
              keep = last[e.key.unescaped.to_sym] == i
              kws << e.key.unescaped.to_sym if keep
              node(u, e.value, !keep)
            end
            flag |= CALL_KWARG
          else
            orig_argc += 1
            flag |= CALL_KW_SPLAT
            flag |= CALL_KW_SPLAT_MUT if els.size > 1
            els.each do |e|
              node(u, e.key, false)
              node(u, e.value, false)
            end
            u.at(*at)
            u.insn(:newhash, els.size * 2)
          end
        when Prism::SplatNode
          flag |= CALL_ARGS_SPLAT
          if a.expression
            node(u, a.expression, false)
          else
            u.at(*at)
            u.insn(:getlocal, *local_ref(u, :*, nil))
          end
          u.at(*at)
          if !has_splat
            if index + 1 < args.size || regular_blockarg
              u.insn(:splatarray, st[0] & SPLATARRAY_TRUE != 0)
              st[0] &= ~SPLATARRAY_TRUE
            else
              u.insn(:splatarray, false)
            end
          else
            u.insn(:concattoarray)
          end
          has_splat = true
          post = 0
        when Prism::ForwardingArgumentsNode
          local = u.local_iseq
          local.params[:use_block] = true
          u.at(*at)
          if local.params[:forwardable]
            flag |= CALL_FORWARDING
            u.insn(:getlocal, *local_ref(u, :"...", nil))
            next
          end
          orig_argc += has_splat ? 1 : 2
          flag |= CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KW_SPLAT
          u.insn(:getlocal, *local_ref(u, :*, nil))
          if has_splat then u.insn(:concattoarray) else u.insn(:splatarray, false) end
          u.insn(:getlocal, *local_ref(u, :**, nil))
          u.insn(:getblockparamproxy, *local_ref(u, :&, nil))
        else
          post += 1
          node(u, a, false)
          if has_splat
            u.at(*at)
            if index == args.size - 1
              u.insn(:pushtoarray, post)
            else
              case args[index + 1]
              when Prism::KeywordHashNode, Prism::SplatNode
                u.insn(:newarray, post)
                u.insn(:concatarray)
              when Prism::ForwardingArgumentsNode
                u.insn(:pushtoarray, post)
              end
            end
          else
            orig_argc += 1
          end
        end
      end
      orig_argc += 1 if has_splat
      orig_argc += 1 if has_kw_splat
      [orig_argc, flag, kws]
    end

    # pm_setup_args_dup_rest_p: whether evaluating n could change an array
    # being splatted
    def dup_rest_p(n)
      case n
      when Prism::BackReferenceReadNode, Prism::ClassVariableReadNode, Prism::ConstantReadNode, Prism::FalseNode,
           Prism::FloatNode, Prism::GlobalVariableReadNode, Prism::ImaginaryNode, Prism::InstanceVariableReadNode,
           Prism::IntegerNode, Prism::LambdaNode, Prism::LocalVariableReadNode, Prism::NilNode,
           Prism::NumberedReferenceReadNode, Prism::RationalNode, Prism::RegularExpressionNode, Prism::SelfNode,
           Prism::StringNode, Prism::SymbolNode, Prism::TrueNode
        false
      when Prism::ConstantPathNode then n.parent ? dup_rest_p(n.parent) : false
      when Prism::ImplicitNode then dup_rest_p(n.value)
      when Prism::ArrayNode then n.elements.any? { |e| dup_rest_p(e) }
      else true
      end
    end

    # (a lambda's sequence starts at its opening and its location at its
    #  parameters, or just after the ->)
    def block_unit(u, b, first_line = nil, start = nil)
      method_unit = u
      method_unit = method_unit.local_iseq
      levels = block_levels(u)
      label = levels == 1 ? "block in #{method_unit.label}" : "block (#{levels} levels) in #{method_unit.label}"
      l = b.location
      start ||= [l.start_line, l.start_column]
      child = Unit.new(:block, label, u.path, u.abs_path, first_line || l.start_line, b.locals, u,
                       [start[0], start[1], l.end_line, l.end_column], b.node_id)
      params(child, b.parameters.is_a?(Prism::BlockParametersNode) ? b.parameters.parameters : nil, b.parameters)
      u.children << child
      opt_defaults(child)
      param_prologue(child, [l.start_line, 0])
      child.at(child.first_lineno, b.node_id)
      child.event(:b_call)
      # (the b_call is a nop's; iseq_optimize takes the nop out again when
      #  nothing comes before it and nothing needs it)
      child.block_nop = child.insn(:nop)
      compile_body(child, b.body, b.node_id, l.end_line)
      finish(child)
      child
    end

    # The parameters, as ruby lays them out in the local table: lead, opt,
    # rest, post, keywords, the hidden kwbits slot, kwrest, block (or for
    # `...` the anonymous *, ** and & and the `...` itself -- that alone
    # when it is the only parameter: forwardable), then the names a
    # destructured parameter binds, then the body's own locals. (a
    # destructured parameter is a hidden local in its place; a block's one
    # required parameter with no optional, rest, post or keyword one --
    # `|y|`, `|y, &b|`, `|(a, b)|`, not `|y,|` -- is ambiguous_param0: the
    # block takes an Array's first element or the whole value, as yield
    # passes it.)
    def params(unit, ps, owner)
      return unless ps
      pr = unit.params
      names = []
      # (the index_lookup_table: where a name is looked up -- for one given
      #  twice, `_`, the place that is not the repeated one)
      lookup = {}
      add = lambda do |name, p = nil|
        lookup[name] = names.size unless name.is_a?(Integer) || (p.respond_to?(:repeated_parameter?) && p.repeated_parameter?)
        names << name
      end
      multis = []
      positional = lambda do |r|
        if r.is_a?(Prism::MultiTargetNode)
          multis << [names.size, r]
          add.(names.size)
        else
          add.(r.name, r)
        end
      end
      ps.requireds.each(&positional)
      pr[:lead_num] = ps.requireds.size
      unless ps.optionals.empty?
        pr[:opt_nodes] = ps.optionals
        ps.optionals.each { |o| add.(o.name, o) }
      end
      if ps.rest && !ps.rest.is_a?(Prism::ImplicitRestNode)
        pr[:rest_start] = names.size
        pr[:anon_rest] = ps.rest.name.nil?
        add.(ps.rest.name || :*, ps.rest)
      end
      unless ps.posts.empty?
        pr[:post_start] = names.size
        pr[:post_num] = ps.posts.size
        ps.posts.each(&positional)
      end
      unless ps.keywords.empty?
        # (a default that is a static literal and no container is kept in
        #  the keyword table; any other is compiled behind checkkeyword)
        kw = ps.keywords.map do |k|
          if k.is_a?(Prism::RequiredKeywordParameterNode) then k.name
          elsif k.value.static_literal? && !container?(k.value) then [k.name, static_value(k.value)]
          else [k.name]
          end
        end
        # (required ones first, as ruby keeps them)
        req = kw.select { |k| k.is_a?(Symbol) }
        opt = kw.reject { |k| k.is_a?(Symbol) }
        pr[:keyword] = req + opt
        pr[:kw_required] = req.size
        pr[:kw_nodes] = ps.keywords
        ps.keywords.grep(Prism::RequiredKeywordParameterNode).each { |k| add.(k.name, k) }
        ps.keywords.grep(Prism::OptionalKeywordParameterNode).each { |k| add.(k.name, k) }
        pr[:kwbits] = names.size
        add.(names.size)
      end
      if ps.keyword_rest.is_a?(Prism::NoKeywordsParameterNode)
        # (**nil: accepts_no_kwarg, which neither to_a nor disasm shows)
        pr[:no_kwarg] = true
      elsif ps.keyword_rest.is_a?(Prism::ForwardingParameterNode)
        if ps.requireds.empty? && ps.optionals.empty? && ps.keywords.empty?
          pr[:forwardable] = true
          pr[:use_block] = true
        else
          pr[:rest_start] = names.size
          pr[:anon_rest] = true
          add.(:*)
          pr[:kwrest] = names.size
          pr[:anon_kwrest] = true
          add.(:**)
          pr[:block_start] = names.size
          add.(:&)
        end
        add.(:"...")
      elsif ps.keyword_rest
        pr[:kwrest] = names.size
        pr[:anon_kwrest] = ps.keyword_rest.name.nil?
        add.(ps.keyword_rest.name || :**, ps.keyword_rest)
      end
      if ps.block
        pr[:block_start] = names.size
        add.(ps.block.name || :&, ps.block)
        pr[:use_block] = true
      end
      unless multis.empty?
        pr[:multis] = multis
        multis.each { |_, m| destructured_locals(m, add) }
      end
      rest_locals = unit.locals.reject { |l| names.include?(l) }
      rest_locals.each { |l| lookup[l] = names.size + rest_locals.index(l) unless lookup.key?(l) }
      unit.locals.replace(names + rest_locals)
      unit.lookup = lookup
      # (ruby asks before it counts **kw and &b: only one local so far)
      if unit.type == :block && ps.requireds.size == 1 && ps.rest.nil? && ps.optionals.empty? && ps.posts.empty? &&
         ps.keywords.empty?
        pr[:ambiguous_param0] = true
      end
    end

    # PM_CONTAINER_P
    def container?(n) = n.is_a?(Prism::ArrayNode) || n.is_a?(Prism::HashNode) || n.is_a?(Prism::RangeNode)

    # pm_compile_destructured_param_locals: the names of a destructured
    # parameter, in order (a repeated one -- `_` again -- has none)
    def destructured_locals(m, add)
      one = ->(r) { add.(r.name, r) unless r.repeated_parameter? }
      m.lefts.each { |l| l.is_a?(Prism::MultiTargetNode) ? destructured_locals(l, add) : one.(l) }
      one.(m.rest.expression) if m.rest.is_a?(Prism::SplatNode) && m.rest.expression
      m.rights.each { |r| r.is_a?(Prism::MultiTargetNode) ? destructured_locals(r, add) : one.(r) }
    end

    # optional parameters' defaults: each behind a label of the opt table,
    # and one after the last -- the body's start
    def opt_defaults(unit)
      nodes = unit.params[:opt_nodes] or return
      labels = []
      nodes.each do |o|
        l = unit.new_label
        unit.emit_label(l)
        labels << l
        node(unit, o.value, false)
        here(unit, o)
        unit.insn(:setlocal, *local_ref(unit, o.name, 0))
      end
      l = unit.new_label
      unit.emit_label(l)
      labels << l
      labels.each { |x| x.unremovable = true; x.refs += 1 }
      unit.params[:opt] = labels
    end

    # pm_compile_scope_node's step 5 past the optional parameters: a
    # keyword default that is not in the table, behind checkkeyword (its
    # bit among the optional keywords), then each destructured parameter
    # taken apart. (at: the scope's place -- its first line, no node)
    def param_prologue(unit, at)
      pr = unit.params
      if pr[:kw_nodes]
        bits = local_op(unit, pr[:kwbits]).idx
        oi = 0
        pr[:kw_nodes].each do |k|
          next unless k.is_a?(Prism::OptionalKeywordParameterNode)
          unless k.value.static_literal? && !container?(k.value)
            done = unit.new_label
            unit.at(*at)
            unit.insn(:checkkeyword, bits, oi)
            unit.insn(:branchif, done)
            node(unit, k.value, false)
            unit.at(*at)
            unit.insn(:setlocal, *local_ref(unit, k.name, 0))
            unit.emit_label(done)
          end
          oi += 1
        end
      end
      (pr[:multis] || []).each do |i, m|
        unit.at(*at)
        unit.insn(:getlocal, local_op(unit, i), 0)
        destructured_writes(unit, m)
      end
    end

    # pm_compile_destructured_param_writes: a multiple assignment whose
    # targets are all the parameter's own locals
    def destructured_writes(unit, m)
      has_rest = m.rest.is_a?(Prism::SplatNode) && !m.rest.expression.nil?
      has_rights = !m.rights.empty?
      write = lambda do |t|
        if t.is_a?(Prism::MultiTargetNode)
          destructured_writes(unit, t)
        else
          here(unit, t)
          unit.insn(:setlocal, *local_ref(unit, t.name, 0))
        end
      end
      here(unit, m)
      unit.insn(:expandarray, m.lefts.size, has_rest || has_rights ? 1 : 0)
      m.lefts.each(&write)
      if has_rest
        if has_rights
          here(unit, m)
          unit.insn(:expandarray, m.rights.size, 3)
        end
        write.(m.rest.expression)
      end
      if has_rights
        unless has_rest
          here(unit, m)
          unit.insn(:expandarray, m.rights.size, 2)
        end
        m.rights.each(&write)
      end
    end

    def define(u, n, popped)
      l = n.location
      child = Unit.new(:method, n.name.to_s, u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      params(child, n.parameters, nil)
      child.detached = true
      # (iseq_location_setup: a method named initialize takes a block)
      child.params[:use_block] = true if n.name == :initialize
      u.children << child
      body = n.body
      first = body.is_a?(Prism::StatementsNode) ? body.body.first : nil
      opt_defaults(child)
      param_prologue(child, [l.start_line, 0])
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
      if n.receiver
        node(u, n.receiver, false)
        here(u, n)
        u.insn(:definesmethod, n.name, child)
      else
        here(u, n)
        u.insn(:definemethod, n.name, child)
      end
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
    # first at the string's own place, a later one at its part's end (an
    # interpolation of a string alone is a literal piece, at the part's
    # start); a lone interpolation has an empty string before it, and
    # pieces that are all literal are one string pushed as it is
    def dstr(u, n, popped)
      if n.is_a?(Prism::InterpolatedStringNode) && n.static_literal?
        # (a static one -- `"#{"a"}"` -- is its string, at its own place)
        unless popped
          here(u, n)
          u.insn(n.frozen? ? :putobject : n.mutable? ? :putstring : :putchilledstring, static_concat(n.parts).freeze)
        end
        return
      end
      count = 0
      cur = nil
      interpolated = false
      cur_at = [n.location.start_line, n.node_id]
      n.parts.each_with_index do |part, i|
        if part.is_a?(Prism::StringNode)
          if cur
            cur << part.unescaped
          else
            cur = part.unescaped.dup
            cur_at = [part.location.end_line, part.node_id] if i != 0
          end
          next
        end
        interpolated = true
        if part.is_a?(Prism::EmbeddedStatementsNode) && part.statements && part.statements.body.size == 1 &&
           part.statements.body[0].is_a?(Prism::StringNode)
          if cur
            cur << part.statements.body[0].unescaped
          else
            cur = part.statements.body[0].unescaped.dup
            cur_at = [part.location.start_line, part.node_id]
          end
          next
        end
        cur = +"" if cur.nil? && n.parts.size == 1
        if cur
          u.at(*cur_at)
          u.insn(:putobject, cur.freeze)
          count += 1
          cur = nil
        end
        case part
        when Prism::EmbeddedStatementsNode
          if part.statements.nil? || part.statements.body.empty?
            raise NotImplementedError, "RubyVM::InstructionSequence: an empty interpolation is not compiled yet"
          end
          node(u, part.statements, false)
        when Prism::InterpolatedStringNode then node(u, part, false)
        else
          raise NotImplementedError, "RubyVM::InstructionSequence: #{part.type} in a string is not compiled yet"
        end
        here(u, part)
        u.insn(:dup)
        u.insn(:objtostring, CallData.new(:to_s, CALL_FCALL | CALL_ARGS_SIMPLE, 0, nil))
        u.insn(:anytostring)
        count += 1
      end
      if cur
        u.at(*cur_at)
        str = n.is_a?(Prism::InterpolatedStringNode)
        u.insn(if count > 0 || (str && n.frozen?) then :putobject
               elsif (str && n.mutable?) || interpolated then :putstring
               else :putchilledstring
               end, cur.freeze)
        count += 1
      end
      here(u, n)
      u.insn(:concatstrings, count) if count > 1
      u.insn(:pop) if popped
    end

    # pm_static_literal_concat: the pieces of a static string, joined
    def static_concat(parts)
      parts.each_with_object(+"") do |part, s|
        case part
        when Prism::StringNode then s << part.unescaped
        when Prism::InterpolatedStringNode then s << static_concat(part.parts)
        when Prism::EmbeddedStatementsNode then s << static_concat(part.statements.body)
        else raise NotImplementedError, "RubyVM::InstructionSequence: #{part.type} in a static string is not compiled yet"
        end
      end
    end

    # PM_HASH_NODE: a static literal is newhash 0 or duphash; popped, only
    # what the elements do; otherwise pm_compile_hash_elements
    def hash_node(u, n, popped)
      if n.static_literal?
        unless popped
          if n.elements.empty? then u.insn(:newhash, 0) else u.insn(:duphash, static_value(n)) end
        end
      elsif popped
        n.elements.each { |e| node(u, e, true) }
      else
        hash_elements(u, n, n.elements, false)
      end
    end

    # pm_compile_hash_elements: runs of pairs pushed and made a hash
    # (newhash, then core#hash_merge_ptr onto it), a leading static run --
    # or one of 0x800 or more -- as a literal hash, and each ** merged in
    # with core#hash_merge_kwd (a call's lone ** is passed as it is)
    MAX_HASH_STACK = 0x100
    MIN_TMP_HASH = 0x800

    def hash_elements(u, n, els, argument)
      at = [n.location.start_line, n.node_id]
      stack = 0
      first = true
      static_run = false
      anchor = []
      flush = lambda do
        next if stack == 0
        if first
          u.append(anchor)
          u.at(*at)
          u.insn(:newhash, stack)
          first = false
        else
          u.at(*at)
          u.insn(:putspecialobject, 1)
          u.insn(:swap)
          u.append(anchor)
          u.at(*at)
          push_send(u, :"core#hash_merge_ptr", stack + 1)
        end
        anchor = []
        stack = 0
      end
      index = 0
      while index < els.size
        e = els[index]
        if e.is_a?(Prism::AssocNode)
          done = false
          if e.static_literal? && ((!static_run && index + MIN_TMP_HASH < els.size) || (first && stack == 0))
            count = 1
            count += 1 while index + count < els.size && els[index + count].static_literal?
            if (first && stack == 0) || count >= MIN_TMP_HASH
              h = {}
              els[index, count].each { |x| h[static_value(x.key)] = static_value(x.value) }
              h.freeze
              index += count - 1
              flush.()
              u.at(*at)
              if first
                u.insn(:duphash, h)
                first = false
              else
                u.insn(:putspecialobject, 1)
                u.insn(:swap)
                u.insn(:putobject, h)
                push_send(u, :"core#hash_merge_kwd", 2)
              end
              done = true
            else
              static_run = true
            end
          else
            static_run = false
          end
          unless done
            anchor.concat(u.capture { node(u, e, false) })
            stack += 2
            flush.() if stack >= MAX_HASH_STACK
          end
        else
          flush.()
          v = e.value
          empty = v && ((v.is_a?(Prism::HashNode) && v.elements.empty?) || v.is_a?(Prism::NilNode))
          first_el = first && stack == 0
          only = first_el && index == els.size - 1
          if empty
            u.at(*at)
            if only && argument then u.insn(:putnil)
            elsif first_el then u.insn(:newhash, 0)
            end
          elsif only && argument
            node(u, e, false)
          else
            u.at(*at)
            u.insn(:putspecialobject, 1)
            if first_el then u.insn(:newhash, 0) else u.insn(:swap) end
            node(u, e, false)
            u.at(*at)
            push_send(u, :"core#hash_merge_kwd", 2)
          end
          first = false
          static_run = false
        end
        index += 1
      end
      flush.()
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
    # (at the top level the scope itself is as a method; from a block ruby
    #  throws TAG_RETURN, which needs the catch table)
    def return_node(u, n, popped)
      unless u.type == :method || u.type == :top
        raise NotImplementedError, "RubyVM::InstructionSequence: return from here is not compiled yet" unless THROUGH.include?(u.type)
        args = n.arguments&.arguments || []
        raise NotImplementedError, "RubyVM::InstructionSequence: return with values is not compiled yet" if args.size > 1
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.insn(:throw, 1)
        u.insn(:pop) if popped
        return
      end
      no_ensure_escape(u, true)
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

    # -- multiple assignment -------------------------------------------------
    # (pm_multi_target_state_t: the topn instructions that reach past the
    #  values to a target's receiver, fixed once every target is known)
    MState = Struct.new(:stack_size, :position, :entries)

    # pm_compile_multi_write_node: the targets' receivers first, the value,
    # its expansion and the writes, then what the receivers left
    def multi_write(u, n, popped)
      writes = []
      cleanup = []
      st = MState.new(0, popped ? 0 : 1, [])
      multi_target(u, n, writes, cleanup, st)
      node(u, n.value, false)
      here(u, n)
      u.insn(:dup) unless popped
      u.append(writes)
      u.insn(:setn, st.stack_size) if !popped && st.stack_size >= 1
      mstate_update(st)
      u.append(cleanup)
    end

    def mstate_push(st, topns, size)
      st.entries << [topns, st.stack_size + 1, size, st.position]
      st.stack_size += size
    end

    def mstate_update(st)
      return if st.stack_size == 0
      st.entries.each do |topns, index, _, position|
        topns.each { |t| t.ops[0] = st.stack_size - index + position }
      end
    end

    # (an instruction for the writes or the cleanup, at a target's place)
    def winsn(arr, t, name, *ops)
      ops.each { |o| o.refs += 1 if o.is_a?(Label) }
      arr << Insn.new(name, ops, t.location.start_line, t.node_id, [])
      arr.last
    end

    def multi_target(u, n, writes, cleanup, st)
      lefts, rest, rights = n.lefts, n.rest, n.rights
      has_rest = rest.is_a?(Prism::SplatNode) && !rest.expression.nil?
      has_posts = !rights.empty?
      winsn(writes, n, :expandarray, lefts.size, (has_rest || has_posts) ? 1 : 0)
      base = st.position
      splat = (has_rest || has_posts) ? 1 : 0
      lefts.each_with_index do |t, i|
        st.position = lefts.size - i + splat + base
        target(u, t, writes, cleanup, st)
      end
      if has_rest
        st.position = 1 + rights.size + base
        winsn(writes, n, :expandarray, rights.size, 3) if has_posts
        target(u, rest.expression, writes, cleanup, st)
      end
      if has_posts
        winsn(writes, n, :expandarray, rights.size, 2) if !has_rest && rest
        rights.each_with_index do |t, i|
          st.position = rights.size - i + base
          target(u, t, writes, cleanup, st)
        end
      end
    end

    # pm_compile_target_node: a receiver into the main sequence, the write
    # into writes, what it leaves into cleanup
    def target(u, t, writes, cleanup, st)
      case t
      when Prism::LocalVariableTargetNode
        ops = local_ref(u, t.name, t.depth)
        winsn(writes, t, u.local_insn_name(:setlocal, ops), *ops)
      when Prism::InstanceVariableTargetNode
        winsn(writes, t, :setinstancevariable, t.name, IVC.new(u.next_is))
      when Prism::GlobalVariableTargetNode
        winsn(writes, t, :setglobal, t.name)
      when Prism::ConstantTargetNode
        winsn(writes, t, :putspecialobject, 3)
        winsn(writes, t, :setconstant, t.name)
      when Prism::ConstantPathTargetNode
        if t.parent then node(u, t.parent, false) else (here(u, t); u.insn(:putobject, Object)) end
        tn = winsn(writes, t, :topn, 1)
        mstate_push(st, [tn], 1)
        winsn(writes, t, :setconstant, t.name)
        winsn(cleanup, t, :pop)
      when Prism::CallTargetNode
        node(u, t.receiver, false)
        safe = nil
        if t.safe_navigation?
          safe = u.new_label
          here(u, t)
          u.insn(:dup)
          u.insn(:branchnil, safe)
        end
        tn = winsn(writes, t, :topn, 1)
        mstate_push(st, [tn], 1)
        winsn(writes, t, :swap)
        flag = CALL_ARGS_SIMPLE
        flag |= CALL_FCALL if t.ignore_visibility?
        winsn(writes, t, :send, CallData.new(t.name, flag, 1, nil), nil)
        winsn(writes, t, :pop)
        writes << safe if safe
        winsn(cleanup, t, :pop)
      when Prism::IndexTargetNode
        node(u, t.receiver, false)
        argc, flag, kws = setup_args(u, t.arguments, t.block, [t.location.start_line, t.node_id])
        raise NotImplementedError, "RubyVM::InstructionSequence: an index target with keywords is not compiled yet" if kws
        topns = [winsn(writes, t, :topn, argc + 1)]
        mstate_push(st, topns, argc + 1)
        if argc == 0
          winsn(writes, t, :swap)
        else
          # (the update reaches the first argc + 1 of them, not the last)
          argc.times { topns << winsn(writes, t, :topn, argc + 1) }
          winsn(writes, t, :topn, argc + 1)
        end
        ci_argc = argc + 1
        if flag & CALL_ARGS_SPLAT != 0
          ci_argc -= 1
          winsn(writes, t, :newarray, 1)
          winsn(writes, t, :concatarray)
        end
        flag |= CALL_ARGS_SIMPLE if (flag & (CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KW_SPLAT)) == 0
        winsn(writes, t, :send, CallData.new(:[]=, flag, ci_argc, nil), nil)
        winsn(writes, t, :pop)
        winsn(writes, t, :pop) if argc != 0
        (argc + 1).times { winsn(cleanup, t, :pop) }
      when Prism::MultiTargetNode
        before = st.position
        st.position -= 1
        multi_target(u, t, writes, cleanup, st)
        st.position = before
      when Prism::SplatNode
        target(u, t.expression, writes, cleanup, st) if t.expression
      else
        raise NotImplementedError, "RubyVM::InstructionSequence: a #{t.type} target is not compiled yet"
      end
    end

    # -- defined? ------------------------------------------------------------
    DEFINED_ASGN_NODES = %w[CallAndWriteNode CallOperatorWriteNode CallOrWriteNode ClassVariableAndWriteNode
      ClassVariableOperatorWriteNode ClassVariableOrWriteNode ClassVariableWriteNode ConstantAndWriteNode
      ConstantOperatorWriteNode ConstantOrWriteNode ConstantPathAndWriteNode ConstantPathOperatorWriteNode
      ConstantPathOrWriteNode ConstantPathWriteNode ConstantWriteNode GlobalVariableAndWriteNode
      GlobalVariableOperatorWriteNode GlobalVariableOrWriteNode GlobalVariableWriteNode IndexAndWriteNode
      IndexOperatorWriteNode IndexOrWriteNode InstanceVariableAndWriteNode InstanceVariableOperatorWriteNode
      InstanceVariableOrWriteNode InstanceVariableWriteNode LocalVariableAndWriteNode
      LocalVariableOperatorWriteNode LocalVariableOrWriteNode LocalVariableWriteNode MultiWriteNode].freeze
    DEFINED_EXPR_NODES = %w[AliasGlobalVariableNode AliasMethodNode AndNode BreakNode CaseMatchNode CaseNode
      ClassNode DefNode DefinedNode FlipFlopNode FloatNode ForNode IfNode ImaginaryNode IntegerNode
      InterpolatedMatchLastLineNode InterpolatedRegularExpressionNode InterpolatedStringNode
      InterpolatedSymbolNode InterpolatedXStringNode LambdaNode MatchLastLineNode MatchPredicateNode
      MatchRequiredNode MatchWriteNode ModuleNode NextNode OrNode PostExecutionNode RangeNode RationalNode
      RedoNode RegularExpressionNode RescueModifierNode RetryNode ReturnNode SingletonClassNode
      SourceEncodingNode SourceFileNode SourceLineNode StringNode SymbolNode UndefNode UnlessNode UntilNode
      WhileNode XStringNode BlockArgumentNode ForwardingArgumentsNode].freeze

    # pm_compile_defined_expr: nothing when popped; otherwise the test, and
    # when a part of it may raise, a putnil before and a swap / pop after
    # for the "defined guard" rescue to land on
    def defined_node(u, n, popped, at = n, cond = false)
      lfin = [u.new_label, nil, nil]
      last = u.elements.size
      defined_expr(u, n.value, at, lfin, cond) unless popped
      if lfin[1]
        u.elements.insert(last, Insn.new(:putnil, [], at.location.start_line, at.node_id, []))
        here(u, at)
        u.insn(:swap)
        u.emit_label(lfin[2]) if lfin[2]
        u.insn(:pop)
        u.emit_label(lfin[1])
      end
      u.emit_label(lfin[0])
    end

    def defined_expr(u, value, at, lfin, cond)
      lcur = u.elements.size
      defined0(u, value, at, cond, lfin, false)
      return unless lfin[1]
      lstart = u.new_label
      lend = u.new_label
      guard = Unit.new(:rescue, "defined guard in #{u.label}", u.path, u.abs_path, 0, [ERRINFO], u, [0, 0, -1, -1], 0)
      guard.parser = :"parse.y"
      guard.at(0, -1)
      guard.insn(:putnil)
      guard.insn(:leave)
      finish(guard)
      u.elements.insert(lcur, lstart)
      u.emit_label(lend)
      u.add_catch(:rescue, lstart, lend, guard, lfin[1])
    end

    # pm_compile_defined_expr0: every instruction at the defined? node's
    # place; in a condition the answer is true, otherwise the type's name
    def defined0(u, n, at, cond, lfin, explicit)
      val = ->(t) { cond ? true : DEFINED_NAMES[DEFINED[t]].dup.freeze }
      loc = -> { here(u, at) }
      type = n.class.name.split("::").last
      dtype = nil
      case n
      when Prism::NilNode then dtype = :nil
      when Prism::SelfNode then dtype = :self
      when Prism::TrueNode then dtype = :true
      when Prism::FalseNode then dtype = :false
      when Prism::LocalVariableReadNode then dtype = :lvar
      when Prism::InstanceVariableReadNode
        loc.()
        return u.insn(:definedivar, n.name, IVC.new(u.next_is), val.(:ivar))
      when Prism::GlobalVariableReadNode, Prism::ClassVariableReadNode, Prism::ConstantReadNode
        t = { Prism::GlobalVariableReadNode => :gvar, Prism::ClassVariableReadNode => :cvar }[n.class] || :const
        loc.()
        u.insn(:putnil)
        return u.insn(:defined, DefType.new(DEFINED[t]), n.name, val.(t))
      when Prism::YieldNode
        u.local_iseq.params[:use_block] = true
        loc.()
        u.insn(:putnil)
        return u.insn(:defined, DefType.new(DEFINED[:yield]), false, val.(:yield))
      when Prism::SuperNode, Prism::ForwardingSuperNode
        if n.block && (n.is_a?(Prism::ForwardingSuperNode) || !n.block.is_a?(Prism::BlockArgumentNode))
          dtype = :expr
        else
          loc.()
          u.insn(:putnil)
          return u.insn(:defined, DefType.new(DEFINED[:zsuper]), false, val.(:zsuper))
        end
      when Prism::ConstantPathNode
        if n.parent
          lfin[1] ||= u.new_label
          defined0(u, n.parent, at, true, lfin, false)
          loc.()
          u.insn(:branchunless, lfin[1])
          node(u, n.parent, false)
        else
          loc.()
          u.insn(:putobject, Object)
        end
        loc.()
        return u.insn(:defined, DefType.new(DEFINED[:const_from]), n.name, val.(:const))
      when Prism::BeginNode
        if n.rescue_clause.nil? && n.ensure_clause.nil? && n.else_clause.nil?
          if n.statements.nil? then dtype = :nil
          elsif n.statements.body.size == 1 then return defined0(u, n.statements.body[0], at, cond, lfin, false)
          else dtype = :expr
          end
        else
          dtype = :expr
        end
      when Prism::ParenthesesNode
        if n.body.nil? then dtype = :nil
        elsif n.body.is_a?(Prism::StatementsNode) && !n.multiple_statements?
          return defined0(u, n.body.body[0], at, cond, lfin, false)
        else dtype = :expr
        end
      when Prism::ArrayNode, Prism::HashNode, Prism::KeywordHashNode, Prism::ArgumentsNode
        list = n.is_a?(Prism::ArrayNode) ? n.elements : (n.is_a?(Prism::ArgumentsNode) ? n.arguments : n.elements)
        lfin[1] ||= u.new_label unless list.empty? || n.is_a?(Prism::ArgumentsNode)
        list.each do |e|
          defined0(u, e, at, n.is_a?(Prism::ArgumentsNode) ? cond : true, lfin, false)
          loc.()
          u.insn(:branchunless, lfin[1])
        end
        dtype = :expr
      when Prism::AssocNode
        defined0(u, n.key, at, true, lfin, false)
        loc.()
        u.insn(:branchunless, lfin[1])
        return defined0(u, n.value, at, true, lfin, false)
      when Prism::AssocSplatNode
        return defined0(u, n.value, at, true, lfin, false) if n.value
        dtype = :expr
      when Prism::ImplicitNode then return defined0(u, n.value, at, cond, lfin, false)
      when Prism::SplatNode
        return (dtype = :expr) && finish_defined(u, at, val, :expr) unless n.expression
        defined0(u, n.expression, at, cond, lfin, false)
        lfin[1] ||= u.new_label
        loc.()
        u.insn(:branchunless, lfin[1])
        dtype = :expr
      when Prism::CallNode
        if n.block.is_a?(Prism::BlockNode)
          dtype = :expr
        else
          blockarg = n.block.is_a?(Prism::BlockArgumentNode)
          if n.receiver || n.arguments || blockarg
            lfin[1] ||= u.new_label
            lfin[2] ||= u.new_label
          end
          if n.arguments
            defined0(u, n.arguments, at, true, lfin, false)
            loc.()
            u.insn(:branchunless, lfin[1])
          end
          if blockarg
            defined0(u, n.block, at, true, lfin, false)
            loc.()
            u.insn(:branchunless, lfin[1])
          end
          if (r = n.receiver)
            if r.is_a?(Prism::CallNode) && !r.block.is_a?(Prism::BlockNode)
              defined0(u, r, at, true, lfin, true)
              loc.()
              u.insn(:branchunless, lfin[2])
              call_rest(u, r)
            else
              defined0(u, r, at, true, lfin, false)
              loc.()
              u.insn(:branchunless, lfin[1])
              node(u, r, false)
            end
            loc.()
            u.insn(:dup) if explicit
            return u.insn(:defined, DefType.new(DEFINED[:method]), n.name, val.(:method))
          else
            loc.()
            u.insn(:putself)
            u.insn(:dup) if explicit
            return u.insn(:defined, DefType.new(DEFINED[:func]), n.name, val.(:method))
          end
        end
      else
        if DEFINED_ASGN_NODES.include?(type) then dtype = :asgn
        elsif DEFINED_EXPR_NODES.include?(type) then dtype = :expr
        else raise NotImplementedError, "RubyVM::InstructionSequence: defined?(#{n.type}) is not compiled yet"
        end
      end
      finish_defined(u, at, val, dtype)
    end

    def call_rest(u, r) = call(u, r, false, true)

    def finish_defined(u, at, val, dtype)
      here(u, at)
      u.insn(:putobject, val.(dtype))
    end

    # -- rescue and ensure ---------------------------------------------------
    ERRINFO = :"$!"

    # a rescue / ensure sequence: its one local is the error ($!)
    def exception_unit(u, type, first_line, loc, node_id)
      child = Unit.new(type, "#{type} in #{u.label}", u.path, u.abs_path, first_line, [ERRINFO], u,
                       [loc.start_line, loc.start_column, loc.end_line, loc.end_column], node_id)
      u.children << child
      child
    end

    # pm_compile_rescue: the body between lstart and lend, the else part,
    # a nop, and the rescue and retry entries; the rescue clauses are a
    # sequence of their own
    def rescue_part(u, n, popped)
      rc = n.rescue_clause
      lstart = u.new_label
      lend = u.new_label
      lcont = u.new_label
      child = exception_unit(u, :rescue, rc.location.start_line, rc.location, rc.node_id)
      node(child, rc, false)
      child.at(rc.location.start_line, 0)
      child.insn(:throw, 0)
      finish(child)
      u.emit_label(lstart)
      if n.statements then node(u, n.statements, false) else (here(u, rc); u.insn(:putnil)) end
      u.emit_label(lend)
      if n.else_clause
        here(u, n)
        u.insn(:pop) unless popped
        node(u, n.else_clause, popped)
      end
      here(u, n)
      u.insn(:nop)
      u.emit_label(lcont)
      u.insn(:pop) if popped
      u.add_catch(:rescue, lstart, lend, child, lcont)
      u.add_catch(:retry, lend, lcont, nil, lstart)
    end

    # pm_compile_rescue_node, in the rescue sequence: each class against $!
    # (checkmatch), the error into its variable, the clause's value left,
    # and the next clause -- or $! thrown on
    def rescue_clause(u, n)
      matched = u.new_label
      none = u.new_label
      at = -> { here(u, n) }
      if n.exceptions.empty?
        at.()
        u.insn(:getlocal, *local_ref(u, ERRINFO, 0))
        u.insn(:putobject, StandardError)
        u.insn(:checkmatch, 3)
        u.insn(:branchif, matched)
      else
        n.exceptions.each do |ex|
          at.()
          u.insn(:getlocal, *local_ref(u, ERRINFO, 0))
          node(u, ex, false)
          at.()
          u.insn(:checkmatch, ex.is_a?(Prism::SplatNode) ? 3 | 4 : 3)
          u.insn(:branchif, matched)
        end
      end
      at.()
      u.insn(:jump, none)
      u.emit_label(matched)
      u.event(:rescue)
      if (r = n.reference)
        at.()
        u.insn(:getlocal, *local_ref(u, ERRINFO, 0))
        u.at(r.location.start_line, r.node_id)
        case r
        when Prism::LocalVariableTargetNode then u.insn(:setlocal, *local_ref(u, r.name, r.depth))
        when Prism::InstanceVariableTargetNode then u.insn(:setinstancevariable, r.name, IVC.new(u.next_is))
        when Prism::GlobalVariableTargetNode then u.insn(:setglobal, r.name)
        else raise NotImplementedError, "RubyVM::InstructionSequence: rescue into #{r.type} is not compiled yet"
        end
      end
      if n.statements then node(u, n.statements, false) else (at.(); u.insn(:putnil)) end
      at.()
      u.insn(:leave)
      u.emit_label(none)
      if n.subsequent
        node(u, n.subsequent, false)
      else
        at.()
        u.insn(:getlocal, *local_ref(u, ERRINFO, 0))
      end
    end

    # x rescue y: the rescue sequence matches StandardError itself
    def rescue_modifier(u, n, popped)
      ex = n.rescue_expression
      child = exception_unit(u, :rescue, ex.location.start_line, n.location, n.node_id)
      matched = child.new_label
      none = child.new_label
      # (the scope's own location: no node)
      child.at(child.first_lineno, 0)
      child.insn(:getlocal, *local_ref(child, ERRINFO, 0))
      child.insn(:putobject, StandardError)
      child.insn(:checkmatch, 3)
      child.insn(:branchif, matched)
      child.insn(:jump, none)
      child.emit_label(matched)
      child.event(:rescue)
      node(child, ex, false)
      child.at(child.first_lineno, 0)
      child.insn(:leave)
      child.emit_label(none)
      child.insn(:getlocal, *local_ref(child, ERRINFO, 0))
      child.insn(:throw, 0)
      finish(child)
      lstart = u.new_label
      lend = u.new_label
      lcont = u.new_label
      u.emit_label(lstart)
      node(u, n.expression, false)
      u.emit_label(lend)
      here(u, n)
      u.insn(:nop)
      u.emit_label(lcont)
      u.insn(:pop) if popped
      u.add_catch(:rescue, lstart, lend, child, lcont)
      u.add_catch(:retry, lend, lcont, nil, lstart)
    end

    # pm_compile_ensure: the ensure clause compiled first (inline, after
    # the body), the body between lstart and lend, then the ensure
    # sequence for the exceptional way out
    def ensure_part(u, n, popped)
      ec = n.ensure_clause
      stmts = ec.statements
      line = stmts ? stmts.location.start_line : n.location.start_line
      lstart = u.new_label
      lend = u.new_label
      lcont = u.new_label
      ensr = u.capture { node(u, stmts, true) if stmts }
      last_leave = ensr.reverse.find { |e| !e.is_a?(Trace) }.then { |e| e.is_a?(Insn) && e.name == :leave }
      u.ensures.push(true)
      u.emit_label(lstart)
      if n.rescue_clause then rescue_part(u, n, popped || last_leave)
      elsif n.statements then node(u, n.statements, popped || last_leave)
      elsif !(popped || last_leave) then synthetic_putnil(u)
      end
      u.emit_label(lend)
      u.ensures.pop
      u.append(ensr)
      here(u, n)
      u.insn(:putnil) if !popped && last_leave
      u.emit_label(lcont)
      u.insn(:pop) if last_leave
      loc = stmts ? stmts.location : ec.location
      child = exception_unit(u, :ensure, line, loc, ec.node_id)
      node(child, ec, true)
      child.at(ec.location.start_line, ec.node_id)
      child.insn(:getlocal, *local_ref(child, ERRINFO, 0))
      child.insn(:throw, 0)
      finish(child)
      i = u.elements.index { |x| x.equal?(lstart) }
      u.add_catch(:ensure, lstart, lend, child, lcont) unless u.elements[i + 1].equal?(lend)
    end

    # (an ensure clause run on the way out of its region -- return, break,
    #  next -- is inlined by pm_add_ensure_iseq; not yet)
    def no_ensure_escape(u, past_loops)
      list = u.ensures
      list = list[((list.rindex(:loop) || -1) + 1)..] unless past_loops
      return unless list.include?(true)
      raise NotImplementedError, "RubyVM::InstructionSequence: leaving an ensure region this way is not compiled yet"
    end

    # prism_compile.c's pm_compile_case_node: the conditions and the bodies
    # built apart; with a subject, a dispatch hash of the literal `when`s,
    # the `===` chain, the else part, then the bodies
    def case_node(u, n, popped)
      end_l = u.new_label
      bodies = []
      if n.predicate.nil?
        conds = u.capture do
          n.conditions.each do |clause|
            label = u.new_label
            bodies << u.capture do
              u.emit_label(label)
              if clause.statements then node(u, clause.statements, popped) elsif !popped then synthetic_putnil(u) end
              here(u, n)
              u.insn(:jump, end_l)
            end
            clause.conditions.each do |c|
              if c.is_a?(Prism::SplatNode)
                here(u, c)
                u.insn(:putnil)
                node(u, c, false)
                here(u, c)
                u.insn(:checkmatch, 1 | 4)
                u.insn(:branchif, label)
              else
                next_l = u.new_label
                branch_condition(u, c, label, next_l)
                u.emit_label(next_l)
              end
            end
          end
          if n.else_clause then node(u, n.else_clause, popped) elsif !popped then synthetic_putnil(u) end
          here(u, n)
          u.insn(:jump, end_l)
        end
        u.append(conds)
      else
        else_l = u.new_label
        dispatch = u.opts[:specialized_instruction] ? {} : nil
        conds = u.capture do
          n.conditions.each do |clause|
            label = u.new_label
            clause.conditions.each do |c|
              key = dispatch && case_key(u, c)
              if key.nil? then dispatch = nil
              else dispatch[key[0]] = label unless dispatch.key?(key[0])
              end
              if c.is_a?(Prism::SplatNode)
                here(u, c)
                u.insn(:dup)
                node(u, c, false)
                here(u, c)
                u.insn(:checkmatch, 2 | 4)
              else
                if c.is_a?(Prism::StringNode)
                  here(u, c)
                  u.insn(:putobject, c.unescaped.dup.freeze)
                else
                  node(u, c, false)
                end
                here(u, c)
                u.insn(:topn, 1)
                u.insn(:send, CallData.new(:===, CALL_FCALL | CALL_ARGS_SIMPLE, 1, nil), nil)
              end
              here(u, c)
              u.insn(:branchif, label)
            end
            bodies << u.capture do
              u.emit_label(label)
              here(u, clause)
              u.insn(:pop)
              if clause.statements then node(u, clause.statements, popped) elsif !popped then synthetic_putnil(u) end
              here(u, clause)
              u.insn(:jump, end_l)
            end
          end
        end
        node(u, n.predicate, false)
        if dispatch
          here(u, n)
          u.insn(:dup)
          u.insn(:opt_case_dispatch, CDHash.new(dispatch.to_a), else_l)
        end
        u.append(conds)
        u.emit_label(else_l)
        if (e = n.else_clause)
          here(u, e.statements || e)
          u.insn(:pop)
          node(u, e, popped)
          here(u, e.statements || e)
          u.insn(:jump, end_l)
        else
          here(u, n)
          u.insn(:pop)
          u.insn(:putnil) unless popped
          u.insn(:jump, end_l)
        end
      end
      bodies.each { |b| u.append(b) }
      u.emit_label(end_l)
    end

    # pm_compile_case_node_dispatch: the key a literal `when` is under, or
    # nil when it has none (and the hash is given up)
    def case_key(u, c)
      case c
      when Prism::FloatNode
        v = c.value
        [v.finite? && v == v.floor ? v.to_i : v]
      when Prism::FalseNode, Prism::IntegerNode, Prism::NilNode, Prism::SymbolNode, Prism::TrueNode
        [static_value(c)]
      when Prism::SourceLineNode then [c.location.start_line]
      when Prism::SourceFileNode then [u.path.dup.freeze]
      when Prism::StringNode then [c.unescaped.dup.freeze]
      end
    end

    # x ||= v / x &&= v, of a local or an instance variable; a local's ||=
    # opens with `putobject true; branchunless` (the peephole drops it)
    def or_and_write(u, n, popped)
      or_ = n.is_a?(Prism::LocalVariableOrWriteNode) || n.is_a?(Prism::InstanceVariableOrWriteNode)
      local = n.is_a?(Prism::LocalVariableOrWriteNode) || n.is_a?(Prism::LocalVariableAndWriteNode)
      end_l = u.new_label
      set_l = nil
      if local && or_
        set_l = u.new_label
        u.insn(:putobject, true)
        u.insn(:branchunless, set_l)
      end
      if local then u.insn(:getlocal, *local_ref(u, n.name, n.depth))
      else u.insn(:getinstancevariable, n.name, IVC.new(u.next_is))
      end
      u.insn(:dup) unless popped
      u.insn(or_ ? :branchif : :branchunless, end_l)
      u.insn(:pop) unless popped
      u.emit_label(set_l) if set_l
      node(u, n.value, false)
      here(u, n)
      u.insn(:dup) unless popped
      if local then u.insn(:setlocal, *local_ref(u, n.name, n.depth))
      else u.insn(:setinstancevariable, n.name, IVC.new(u.next_is))
      end
      u.emit_label(end_l)
    end

    # $g / X &&= v and ||= v: an ||= asks defined? first, so that reading
    # what is not there yet does not warn or raise
    def var_and_or_write(u, n, popped)
      or_ = n.is_a?(Prism::GlobalVariableOrWriteNode) || n.is_a?(Prism::ConstantOrWriteNode)
      const = n.is_a?(Prism::ConstantAndWriteNode) || n.is_a?(Prism::ConstantOrWriteNode)
      end_l = u.new_label
      set_l = nil
      if or_
        set_l = u.new_label
        u.insn(:putnil)
        u.insn(:defined, DefType.new(DEFINED[const ? :const : :gvar]), n.name, true)
        u.insn(:branchunless, set_l)
      end
      if const then constant_read(u, n.name, n.name_loc, n) else u.insn(:getglobal, n.name) end
      here(u, n)
      u.insn(:dup) unless popped
      u.insn(or_ ? :branchif : :branchunless, end_l)
      u.insn(:pop) unless popped
      u.emit_label(set_l) if set_l
      node(u, n.value, false)
      here(u, n)
      u.insn(:dup) unless popped
      if const
        u.insn(:putspecialobject, 3)
        u.insn(:setconstant, n.name)
      else
        u.insn(:setglobal, n.name)
      end
      u.emit_label(end_l)
    end

    def constant_path_split(u, n, prefix, body)
      case n
      when Prism::ConstantReadNode
        body.concat(u.capture { here(u, n); u.insn(:putobject, true); u.insn(:getconstant, n.name) })
      when Prism::ConstantPathNode
        if n.parent.nil?
          body.concat(u.capture do
            here(u, n)
            u.insn(:pop)
            u.insn(:putobject, Object)
            u.insn(:putobject, true)
            u.insn(:getconstant, n.name)
          end)
        else
          constant_path_split(u, n.parent, prefix, body)
          body.concat(u.capture { here(u, n); u.insn(:putobject, false); u.insn(:getconstant, n.name) })
        end
      else
        prefix.concat(u.capture { node(u, n, false) })
      end
    end

    # pm_compile_shareable_constant_literal: [the value] when n is a
    # literal ruby makes shareable as it compiles, nil otherwise
    def shareable_literal(n)
      case n
      when Prism::TrueNode, Prism::FalseNode, Prism::NilNode, Prism::SymbolNode, Prism::RegularExpressionNode,
           Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode
        [static_value(n)]
      when Prism::SourceLineNode then [n.location.start_line]
      when Prism::StringNode then [n.unescaped.dup.freeze]
      when Prism::ArrayNode
        vs = n.elements.map { |e| shareable_literal(e) or return nil }
        [vs.map(&:first).freeze]
      when Prism::HashNode
        h = {}
        n.elements.each do |e|
          return nil unless e.is_a?(Prism::AssocNode)
          k = shareable_literal(e.key) or return nil
          v = shareable_literal(e.value) or return nil
          h[k[0]] = v[0]
        end
        [h.freeze]
      end
    end

    # pm_compile_constant_read: at the name, of the node it is read for
    def constant_read(u, name, loc, n)
      u.at(loc.start_line, n.node_id)
      if u.opts[:inline_const_cache]
        u.insn(:opt_getconstant_path, IC.new(u.next_ic, [name]))
      else
        u.insn(:putnil)
        u.insn(:putobject, true)
        u.insn(:getconstant, name)
      end
    end

    # pm_compile_constant_path_*_write_node: the owner (Object for ::X)
    # stays under the value; the constant is read with getconstant
    def constant_path_write(u, n, popped)
      t = n.target
      if t.parent then node(u, t.parent, false) else u.insn(:putobject, Object) end
      here(u, n)
      case n
      when Prism::ConstantPathWriteNode
        node(u, n.value, false)
        here(u, n)
        unless popped
          u.insn(:swap)
          u.insn(:topn, 1)
        end
        u.insn(:swap)
        u.insn(:setconstant, t.name)
      when Prism::ConstantPathOperatorWriteNode
        u.insn(:dup)
        u.insn(:putobject, true)
        u.insn(:getconstant, t.name)
        node(u, n.value, false)
        here(u, n)
        u.insn(:send, CallData.new(n.binary_operator, CALL_FCALL | CALL_ARGS_SIMPLE, 1, nil), nil)
        u.insn(:swap)
        unless popped
          u.insn(:topn, 1)
          u.insn(:swap)
        end
        u.insn(:setconstant, t.name)
      else
        or_ = n.is_a?(Prism::ConstantPathOrWriteNode)
        lfin = u.new_label
        lassign = nil
        if or_
          lassign = u.new_label
          u.insn(:dup)
          u.insn(:defined, DefType.new(DEFINED[:const_from]), t.name, true)
          u.insn(:branchunless, lassign)
        end
        u.insn(:dup)
        u.insn(:putobject, true)
        u.insn(:getconstant, t.name)
        u.insn(:dup) unless popped
        u.insn(or_ ? :branchif : :branchunless, lfin)
        u.insn(:pop) unless popped
        u.emit_label(lassign) if lassign
        node(u, n.value, false)
        here(u, n)
        if popped
          u.insn(:topn, 1)
        else
          u.insn(:dupn, 2)
          u.insn(:swap)
        end
        u.insn(:setconstant, t.name)
        u.emit_label(lfin)
        u.insn(:swap) unless popped
        u.insn(:pop)
      end
    end

    # pm_compile_call_and_or_write_node: r.x &&= v / r.x ||= v (FCALL for
    # self alone), with &. skipping it all on nil
    def call_and_or_write(u, n, popped)
      raise NotImplementedError, "RubyVM::InstructionSequence: a call write without a receiver is not compiled yet" unless n.receiver
      and_ = n.is_a?(Prism::CallAndWriteNode)
      lfin = u.new_label
      lcfin = u.new_label
      lskip = nil
      flag = n.receiver.is_a?(Prism::SelfNode) ? CALL_FCALL : 0
      node(u, n.receiver, false)
      here(u, n)
      if n.safe_navigation?
        lskip = u.new_label
        u.insn(:dup)
        u.insn(:branchnil, lskip)
      end
      u.insn(:dup)
      push_send(u, n.read_name, 0, flag)
      u.insn(:dup) unless popped
      u.insn(and_ ? :branchunless : :branchif, lcfin)
      u.insn(:pop) unless popped
      node(u, n.value, false)
      here(u, n)
      unless popped
        u.insn(:swap)
        u.insn(:topn, 1)
      end
      push_send(u, n.write_name, 1, flag)
      u.insn(:jump, lfin)
      u.emit_label(lcfin)
      u.insn(:swap) unless popped
      u.emit_label(lfin)
      u.emit_label(lskip) if lskip && popped
      u.insn(:pop)
      u.emit_label(lskip) if lskip && !popped
    end

    # pm_compile_call_operator_write_node: r.x op= v
    def call_operator_write(u, n, popped)
      flag = n.ignore_visibility? ? CALL_FCALL : 0
      node(u, n.receiver, false)
      here(u, n)
      safe = nil
      if n.safe_navigation?
        safe = u.new_label
        u.insn(:dup)
        u.insn(:branchnil, safe)
      end
      u.insn(:dup)
      push_send(u, n.read_name, 0, flag)
      node(u, n.value, false)
      here(u, n)
      push_send(u, n.binary_operator, 1)
      unless popped
        u.insn(:swap)
        u.insn(:topn, 1)
      end
      push_send(u, n.write_name, 1, flag)
      u.emit_label(safe) if safe && popped
      u.insn(:pop)
      u.emit_label(safe) if safe && !popped
    end

    # pm_compile_index_operator_write_node and
    # pm_compile_index_control_flow_write_node: the receiver and the
    # arguments kept (dupn) for the [] and then the []=, the new value
    # moved in under them as the last argument -- onto a splat's array, or
    # past keywords (opt_reverse)
    def index_write(u, n, popped)
      at = [n.location.start_line, n.node_id]
      op = n.is_a?(Prism::IndexOperatorWriteNode)
      u.insn(:putnil) unless popped
      node(u, n.receiver, false)
      boff = n.block ? 1 : 0
      flag = n.receiver.is_a?(Prism::SelfNode) ? CALL_FCALL : 0
      argc, flag, kws = setup_args(u, n.arguments, n.block, at, flag)
      u.at(*at)
      if (argc > 0 || boff == 1) && flag & CALL_KW_SPLAT != 0
        if boff == 1
          u.insn(:splatkw)
        else
          u.insn(:dup)
          u.insn(:splatkw)
          u.insn(:pop)
        end
      end
      dup_argn = argc + 1 + boff
      klen = kws ? kws.size : 0
      dup_argn += klen
      u.insn(:dupn, dup_argn)
      push_send(u, :[], argc, flag & ~(CALL_ARGS_SPLAT_MUT | CALL_KW_SPLAT_MUT), kws)
      label = lfin = nil
      if op
        node(u, n.value, false)
        u.at(*at)
        push_send(u, n.binary_operator, 1)
      else
        label = u.new_label
        lfin = u.new_label
        u.insn(:dup)
        u.insn(n.is_a?(Prism::IndexAndWriteNode) ? :branchunless : :branchif, label)
        u.insn(:pop)
        node(u, n.value, false)
        u.at(*at)
      end
      u.insn(:setn, dup_argn + 1) unless popped
      if flag & CALL_ARGS_SPLAT != 0
        if flag & CALL_KW_SPLAT != 0
          u.insn(:topn, 2 + boff)
          if flag & CALL_ARGS_SPLAT_MUT == 0
            u.insn(:splatarray, true)
            flag |= CALL_ARGS_SPLAT_MUT
          end
          u.insn(:swap)
          u.insn(:pushtoarray, 1)
          u.insn(:setn, 2 + boff)
          u.insn(:pop)
        else
          if boff > 0
            u.insn(:dupn, 3)
            u.insn(:swap)
            u.insn(:pop)
          end
          if flag & CALL_ARGS_SPLAT_MUT == 0
            u.insn(:swap)
            u.insn(:splatarray, true)
            u.insn(:swap)
            flag |= CALL_ARGS_SPLAT_MUT
          end
          u.insn(:pushtoarray, 1)
          if boff > 0
            u.insn(:setn, 3)
            u.insn(:pop)
            u.insn(:pop)
          end
        end
        push_send(u, :[]=, argc, flag, kws)
      elsif flag & CALL_KW_SPLAT != 0
        if boff > 0
          u.insn(:topn, 2)
          u.insn(:swap)
          u.insn(:setn, 3)
          u.insn(:pop)
        end
        u.insn(:swap)
        push_send(u, :[]=, argc + 1, flag, kws)
      elsif klen > 0
        if op
          u.insn(:dup)
          u.insn(:opt_reverse, klen + boff + 2)
          u.insn(:opt_reverse, klen + boff + 1)
          u.insn(:pop)
        else
          u.insn(:opt_reverse, klen + boff + 1)
          u.insn(:opt_reverse, klen + boff)
        end
        push_send(u, :[]=, argc + 1, flag, kws)
      else
        u.insn(:swap) if boff > 0
        push_send(u, :[]=, argc + 1, flag, kws)
      end
      u.insn(:pop)
      return if op
      u.insn(:jump, lfin)
      u.emit_label(label)
      u.insn(:setn, dup_argn + 1) unless popped
      u.insn(:adjuststack, dup_argn + 1)
      u.emit_label(lfin)
    end

    # class << x: a class sequence "singleton class", defineclass with
    # the singleton flag
    def singleton_class(u, n, popped)
      l = n.location
      child = Unit.new(:class, "singleton class", u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      child.detached = true
      u.children << child
      class_body(child, n)
      node(u, n.expression, false)
      here(u, n)
      u.insn(:putnil)
      u.insn(:defineclass, :singletonclass, child, 1)
      u.insn(:pop) if popped
    end

    def yield_node(u, n, popped)
      m = u
      m = m.local_iseq
      m.params[:use_block] = true if m.type == :method
      argc, flag, kws = setup_args(u, n.arguments, nil, [n.location.start_line, n.node_id])
      here(u, n)
      u.insn(:invokeblock, ci(nil, argc, flag, kws))
      u.insn(:pop) if popped
    end

    def class_node(u, n, popped)
      mod = n.is_a?(Prism::ModuleNode)
      name = n.constant_path.is_a?(Prism::ConstantReadNode) ? n.constant_path.name : n.constant_path.name
      l = n.location
      child = Unit.new(:class, "<#{mod ? "module" : "class"}:#{name}>", u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      u.children << child
      class_body(child, n)
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

    # (a singleton class has no class / end events, and its leave stays on
    #  the last line)
    def class_body(child, n)
      l = n.location
      events = !n.is_a?(Prism::SingletonClassNode)
      child.at(l.start_line, n.node_id)
      child.event(:class) if events
      # (an empty body's putnil is synthetic: node 0)
      if n.body then node(child, n.body, false) else (child.at(l.start_line, 0); child.insn(:putnil)) end
      if events
        child.event(:end)
        child.last_line = l.end_line
      end
      child.last_line ||= l.start_line
      child.at(child.last_line, n.node_id)
      child.insn(:leave)
      finish(child)
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
        synthetic_putnil(u)
      end
    end

    # PUSH_SYNTHETIC_PUTNIL: on the last line, of no node (-1)
    def synthetic_putnil(u)
      u.at(u.last_line || u.line, -1)
      u.insn(:putnil)
    end

    # pm_compile_logical: one side of && / || in a condition, falling through
    # to a label of its own for the other
    def compile_logical(u, cond, then_l, else_l)
      lbl = u.new_label
      then_l ||= lbl
      else_l ||= lbl
      start = u.elements.size
      branch_condition(u, cond, then_l, else_l)
      chunk = u.elements[start..]
      insns = chunk.grep(Insn)
      if insns.size == 1 && insns[0].name == :jump && insns[0].ops[0].equal?(lbl)
        unref(insns[0])
        u.elements.slice!(start..)
        return
      end
      u.emit_label(lbl) if lbl.refs > 0
    end

    # pm_compile_branch_condition (its location is the condition it was
    # given, kept as it walks into && / ||)
    def branch_condition(u, cond, then_l, else_l, at = cond)
      case cond
      when Prism::FalseNode, Prism::NilNode
        here(u, at)
        u.insn(:jump, else_l)
        return
      when Prism::FloatNode, Prism::ImaginaryNode, Prism::IntegerNode, Prism::RationalNode,
           Prism::StringNode, Prism::SymbolNode, Prism::TrueNode, Prism::LambdaNode, Prism::RegularExpressionNode
        here(u, at)
        u.insn(:jump, then_l)
        return
      when Prism::DefinedNode
        # (in a condition the answer is true, at the condition's place)
        defined_node(u, cond, false, at, true)
        here(u, at)
        u.insn(:branchunless, else_l)
        u.insn(:jump, then_l)
        return
      when Prism::AndNode
        compile_logical(u, cond.left, nil, else_l)
        return branch_condition(u, cond.right, then_l, else_l, at)
      when Prism::OrNode
        compile_logical(u, cond.left, then_l, nil)
        return branch_condition(u, cond.right, then_l, else_l, at)
      end
      start = u.elements.size
      node(u, cond, false)
      chunk = u.elements[start..].grep(Insn)
      if chunk.size == 1 && chunk[0].name == :putobject
        u.elements.delete(chunk[0])
        here(u, at)
        u.insn(:jump, chunk[0].ops[0] ? then_l : else_l)
        return
      end
      here(u, at)
      u.insn(:branchunless, else_l)
      u.insn(:jump, then_l)
    end

    # prism_compile.c's pm_compile_loop: the next / redo / break labels,
    # the adjust block a `next` lands in, and the condition at the bottom;
    # compile.c's peephole turns `branchunless end; jump redo` into one
    # `branchif redo` (`branchunless` for until)
    def loop_node(u, n, popped)
      until_ = n.is_a?(Prism::UntilNode)
      next_l = u.new_label
      redo_l = u.new_label
      break_l = u.new_label
      end_l = u.new_label
      adjust_l = u.new_label
      next_catch_l = u.new_label
      # (begin ... end while runs the body first)
      tmp_l = n.begin_modifier? ? u.new_label : nil
      u.insn(:jump, tmp_l || next_l)
      u.emit_label(adjust_l)
      u.insn(:putnil)
      u.emit_label(next_catch_l)
      u.insn(:pop)
      u.insn(:jump, next_l)
      u.emit_label(tmp_l) if tmp_l
      u.emit_label(redo_l)
      u.loops.push([next_l, break_l, redo_l])
      u.ensures.push(:loop)
      node(u, n.statements, true) if n.statements
      u.ensures.pop
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
      u.add_catch(:break, redo_l, break_l, nil, break_l)
      u.add_catch(:next, redo_l, break_l, nil, next_catch_l)
      u.add_catch(:redo, redo_l, break_l, nil, redo_l)
    end

    # pm_compile_next_node. In a loop: its value, the stack back to the
    # loop's (an ADJUST to the redo label) and the condition again. In a
    # block: the stack back to the block's start, its value, a jump to the
    # block's end.
    def next_node(u, n, popped)
      args = n.arguments&.arguments || []
      raise NotImplementedError, "RubyVM::InstructionSequence: next with values" if args.size > 1
      sp = u.new_label
      no_ensure_escape(u, false) if u.loops.last || u.type == :block
      if (lp = u.loops.last)
        u.emit_label(sp)
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.adjust(lp[2], false)
        u.insn(:jump, lp[0])
      elsif u.type == :block
        u.emit_label(sp)
        here(u, n)
        u.adjust(u.block_labels[0], false)
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.insn(:jump, u.block_labels[1])
        u.adjust(sp, true)
        sp.unremovable = false
        u.insn(:putnil) unless popped
        return
      elsif escape_scope(u)
        # (from a rescue / ensure sequence: thrown to the block or loop)
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.insn(:throw, THROW_NO_ESCAPE | 3)
        u.insn(:pop) if popped
        return
      else
        raise NotImplementedError, "RubyVM::InstructionSequence: next here is not compiled yet"
      end
      u.adjust(sp, true)
      u.insn(:putnil) unless popped
    end

    THROW_NO_ESCAPE = 0x8000

    # the sequence a throwing break / next goes to: the nearest one that is
    # in a loop or is a block, out through rescue and ensure sequences
    def escape_scope(u)
      ip = u
      while ip
        return ip if !ip.loops.empty? || ip.type == :block
        return nil unless THROUGH.include?(ip.type)
        ip = ip.parent
      end
      nil
    end

    # pm_compile_break_node: in a loop, the stack back to the loop's and a
    # jump past it; in a block, a throw (TAG_BREAK) the call's break entry
    # catches
    def break_node(u, n, popped)
      args = n.arguments&.arguments || []
      raise NotImplementedError, "RubyVM::InstructionSequence: break with values" if args.size > 1
      if (lp = u.loops.last)
        no_ensure_escape(u, false)
        sp = u.new_label
        u.emit_label(sp)
        here(u, n)
        u.adjust(lp[2], false)
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.insn(:jump, lp[1])
        u.adjust(sp, true)
        u.insn(:putnil) unless popped
      elsif (ip = escape_scope(u))
        # (a loop's break from a rescue / ensure sequence does not escape
        #  the frame: VM_THROW_NO_ESCAPE_FLAG)
        if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
        here(u, n)
        u.insn(:throw, ip.loops.empty? ? 2 : THROW_NO_ESCAPE | 2)
        u.insn(:pop) if popped
      else
        raise NotImplementedError, "RubyVM::InstructionSequence: break here is not compiled yet"
      end
    end

    # -- the backend (compile.c's iseq_setup): peephole and specialised
    # instructions, operand unification, the stack depth, the layout ----
    def finish(u)
      u.elements.each { |e| e.ops.each { |o| o.base = u.ivc_size if o.is_a?(IC) } if e.is_a?(Insn) }
      optimize(u)
      drop_block_nop(u)
      nop_between_end_and_cont(u)
      # (update_catch_except_flags: a throw may be caught around here; an
      #  entry other than break / next / redo catches an exception)
      u.set_catch_except if u.elements.any? { |e| e.is_a?(Insn) && e.name == :throw }
      u.catch_except = true if (u.catch || []).any? { |c| !%i[break next redo].include?(c[0]) }
      attach_traces(u)
      u.stack_max = stack_max(u)
      pos = 0
      u.elements.each do |e|
        if e.is_a?(Label) then e.pos = pos
        elsif e.is_a?(Insn) then pos += 1 + e.ops.size
        end
      end
    end

    # iseq_optimize's block optimisation: a block's leading nop goes when
    # it is the block's first instruction, no throw is in the block and no
    # jump goes back to the label after it
    def drop_block_nop(u)
      nop = u.block_nop or return
      els = u.elements
      i = els.index { |x| x.equal?(nop) } or return
      return unless i == 1
      after = els[i + 1].is_a?(Label) ? els[i + 1] : nil
      els.each do |e|
        next unless e.is_a?(Insn)
        return if e.name == :throw
        return if after && e.ops.any? { |o| o.equal?(after) }
      end
      els.delete_at(i)
    end

    # iseq_insert_nop_between_end_and_cont: a rescue / ensure entry whose
    # end runs straight into its continuation gets a nop between (line 0,
    # no node)
    def nop_between_end_and_cont(u)
      (u.catch || []).each do |t, _, le, _, lc|
        next if %i[break next redo].include?(t)
        i = u.elements.index { |x| x.equal?(le) } or next
        j = i
        while j < u.elements.size && (u.elements[j].is_a?(Label) || u.elements[j].is_a?(Trace))
          if u.elements[j].equal?(lc)
            u.elements.insert(i + 1, Insn.new(:nop, [], 0, -1, []))
            break
          end
          j += 1
        end
      end
    end

    def insn_at(els, i)
      i += 1 while i < els.size && !(els[i].is_a?(Insn) || els[i].is_a?(Adjust))
      i < els.size ? i : nil
    end

    def dest_index(els, label) = insn_at(els, els.index { |x| x.equal?(label) } + 1)

    def unref(e) = e.ops.each { |o| o.refs -= 1 if o.is_a?(Label) }

    # compile.c's iseq_optimize: each instruction in turn gets the peephole
    # rules, then its specialised instruction, then operand unification --
    # so a rule looking back sees what came before already specialised and
    # unified, and one looking ahead sees it as it was built. (One a rule
    # took out goes on with what followed it; one a rule moved goes on from
    # its new place, past what it was moved over.)
    def optimize(u)
      o = u.opts
      els = u.elements
      i = 0
      while i < els.size
        e = els[i]
        unless e.is_a?(Insn)
          i += 1
          next
        end
        cont = i
        if o[:peephole_optimization]
          loop do
            r = peephole_insn(u, els, i)
            # (`goto again`: the same instruction, wherever it is now)
            if r == :again && (j = locate(els, e, i))
              i = j
              next
            end
            cont = r.is_a?(Integer) ? r : i
            break
          end
        end
        unless (j = locate(els, e, i))
          i = cont
          next
        end
        if o[:specialized_instruction]
          specialize_insn(els, j)
          unless (k = locate(els, e, j))
            i = j
            next
          end
          j = k
        end
        unify_insn(e) if o[:operands_unification]
        i = j + 1
      end
    end

    def locate(els, e, hint)
      return hint if els[hint].equal?(e)
      els.index { |x| x.equal?(e) }
    end

    def insn_named?(x, *names) = x.is_a?(Insn) && names.include?(x.name)

    def simple?(cd) = cd.is_a?(CallData) && cd.flag & CALL_ARGS_SIMPLE != 0

    # (is_frozen_putstring and its like: a string pushed as it is)
    def string_push?(x)
      x.is_a?(Insn) && (x.name == :putstring || x.name == :putchilledstring ||
                        (x.name == :putobject && x.ops[0].is_a?(String)))
    end

    # (the same local at the same level)
    def same_local?(a, b) = a.ops[0].idx == b.ops[0].idx && a.ops[1] == b.ops[1]

    # insn_has_label_before: a label some jump still names, between it and
    # the instruction before
    def label_before?(els, k)
      k -= 1
      while k >= 0 && !els[k].is_a?(Insn)
        return true if els[k].is_a?(Label) && els[k].refs > 0
        k -= 1
      end
      false
    end

    # (a send of freeze, simple, with no arguments and no block)
    def freeze_send?(x)
      insn_named?(x, :send) && simple?(cd = x.ops[0]) && cd.argc == 0 && x.ops[1].nil? && cd.mid == :freeze
    end

    # compile.c's iseq_peephole_optimize: its rules in its order, several of
    # them on one instruction (not the tail call, which this compiler
    # refuses, nor opt_invokebuiltin_delegate, which it never emits). It
    # answers :again to run them all again on the instruction (`goto
    # again`), or, when it took the instruction out, where to go on
    def peephole_insn(u, els, i)
      e = els[i]
      if e.name == :jump
        d = dest_index(els, e.ops[0])
        nx = insn_at(els, i + 1)
        if d && d == nx
          unref(e)
          els.delete_at(i)
          return i
        end
        de = d && els[d]
        if de.is_a?(Insn) && de.name == :jump && !de.ops[0].equal?(e.ops[0]) && traces_before(els, d).empty?
          e.ops[0].refs -= 1
          e.ops[0] = de.ops[0]
          e.ops[0].refs += 1
          remove_unreachable(els, i + 1)
          return :again
        elsif de.is_a?(Insn) && de.name == :leave
          # (it takes the leave's insn_info, the events
          #  get_destination_insn gave it included)
          unref(e)
          e.name = :leave
          e.ops = []
          e.line, e.node_id = de.line, de.node_id
          tr = traces_before(els, d).reverse.map { |t| Trace.new(t.event) }
          els.insert(i, *tr)
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
            return i
          elsif d && pd == d
            # (a branch to where the jump goes anyway is a pop, at the
            #  jump's place)
            unref(pe)
            els[pi] = Insn.new(:pop, [], e.line, e.node_id, [])
          end
        end
        return :again if remove_unreachable(els, i + 1)
        return nil
      end

      # (two strings, frozen, and a newrange of them are the range itself,
      #  when no jump lands between)
      if e.name == :newrange
        ei = prev_insn(els, i)
        bi = ei && prev_insn(els, ei)
        if bi && string_push?(els[ei]) && string_push?(els[bi]) && !label_before?(els, bi) && !label_before?(els, ei)
          range = Range.new(els[bi].ops[0], els[ei].ops[0], e.ops[0] == 1).freeze
          els.delete_at(ei)
          els.delete_at(bi)
          i -= 2
          e.name = :putobject
          e.ops = [range]
        end
      end

      remove_unreachable(els, i + 1) if e.name == :leave

      # (an array concatarray / concattoarray only reads needs no copy)
      e.name = :putobject if e.name == :duparray && insn_named?(els[i + 1], :concatarray, :concattoarray)

      # (a literal array or hash, or an empty one, sent freeze is
      #  opt_ary_freeze / opt_hash_freeze of it, the send's calldata kept)
      if (e.name == :duparray || e.name == :duphash || (e.name == :newarray || e.name == :newhash) && e.ops[0] == 0) &&
         freeze_send?(els[i + 1])
        obj = case e.name
              when :duparray, :duphash then e.ops[0]
              when :newarray then [].freeze
              else {}.freeze
              end
        e.name = %i[duparray newarray].include?(e.name) ? :opt_ary_freeze : :opt_hash_freeze
        e.ops = [obj, els[i + 1].ops[0]]
        els.delete_at(i + 1)
      end

      return peephole_branch(els, i) if %i[branchif branchunless branchnil].include?(e.name)

      if e.name == :pop
        pe = i > 0 && els[i - 1]
        if pe.is_a?(Insn) && POP_SILENT.include?(pe.name)
          els.delete_at(i)
          els.delete_at(i - 1)
          return i - 1
        elsif pe.is_a?(Insn) && pe.name == :newarray
          # (iseq_pop_newarray: none -- nothing; one -- the pop stays;
          #  more -- adjuststack)
          case pe.ops[0]
          when 0
            els.delete_at(i)
            els.delete_at(i - 1)
            return i - 1
          when 1
            # (compile.c goes on past the pop: it is not looked at again)
            els.delete_at(i - 1)
            return nil
          else
            pe.name = :adjuststack
            els.delete_at(i)
            return i
          end
        elsif pe.is_a?(Insn) && pe.name == :concatarray
          # (the two arrays are only popped: the one on top is still
          #  splatted, as concatarray would)
          els.insert(i - 1, Insn.new(:splatarray, [false], pe.line, pe.node_id, []))
          pe.name = :pop
          return nil
        elsif pe.is_a?(Insn) && pe.name == :concatstrings
          if pe.ops[0] == 1
            els.delete_at(i - 1)
            return nil
          end
          els.delete_at(i)
          pe.name = :adjuststack
          return i
        end
      end

      # (an instruction that always pushes an array needs no splatarray)
      if %i[newarray duparray concatarray splatarray].include?(e.name) && insn_named?(els[i + 1], :splatarray)
        els.delete_at(i + 1)
      end

      # (an array built only to be taken apart again: the values as they
      #  are -- swapped, reversed, the extra popped, the missing nil)
      if e.name == :newarray && insn_named?(els[i + 1], :expandarray) && els[i + 1].ops[1] == 0
        x = e.ops[0]
        y = els[i + 1].ops[0]
        els.delete_at(i + 1)
        if x == y
          if x == 2
            e.name = :swap
            e.ops = []
          else
            e.name = :opt_reverse
          end
        else
          e.name = :opt_reverse
          e.ops = [y]
          filler = x > y ? :pop : :putnil
          (x - y).abs.times do
            els.insert(i, Insn.new(filler, [], e.line, e.node_id, []))
            i += 1
          end
        end
      end

      # (a literal array expandarray only reads needs no copy)
      e.name = :putobject if e.name == :duparray && insn_named?(els[i + 1], :expandarray)

      # (concatstrings of one string is that string)
      if e.name == :anytostring && insn_named?(els[i + 1], :concatstrings) && els[i + 1].ops[0] == 1
        els.delete_at(i + 1)
      end

      # (an empty string adds nothing to a concatstrings; one folding a
      #  string into a toregexp is not here: nothing emits toregexp yet)
      if string_push?(e) && insn_named?(els[i + 1], :concatstrings) && e.ops[0].empty?
        n = els[i + 1].ops[0] - 1
        els[i + 1].ops = [n]
        els.delete_at(i + 1) if n == 1
        els.delete_at(i)
        return i
      end

      # (concatstrings of a concatstrings, straight after it or past a
      #  jump, is one: the jump then lands after the second)
      if e.name == :concatstrings
        k = i + 1
        jmp = nil
        if insn_named?(els[k], :jump)
          jmp = els[k]
          k = dest_index(els, jmp.ops[0])
        end
        nx = k && els[k]
        if insn_named?(nx, :concatstrings)
          e.ops = [e.ops[0] + nx.ops[0] - 1]
          if jmp
            l = jmp.ops[0]
            l.refs -= 1
            if l.refs == 0
              els.delete_at(els.index { |x| x.equal?(l) })
            else
              l = u.new_label
              jmp.ops[0] = l
            end
            l.refs += 1
            els.insert(els.index { |x| x.equal?(nx) } + 1, l)
            ni = insn_at(els, els.index { |x| x.equal?(jmp) } + 1)
            if ni && (ne = els[ni]).is_a?(Insn)
              loop do
                break unless peephole_insn(u, els, ni) == :again && (ni = locate(els, ne, ni))
              end
            end
          else
            els.delete_at(k)
          end
        end
      end

      if e.name == :dup && insn_named?(els[i + 1], :setlocal)
        s1 = els[i + 1]
        if insn_named?(els[i + 2], :setlocal)
          # (dup, setlocal x, setlocal x: the setlocal once)
          if same_local?(s1, els[i + 2])
            els.delete_at(i + 1)
            els.delete_at(i)
            return i
          end
        elsif insn_named?(els[i + 2], :dup) && insn_named?(els[i + 3], :setlocal)
          # (dup, setlocal x, dup, setlocal x: the first pair once)
          if same_local?(s1, els[i + 3])
            els.delete_at(i + 3)
            els.delete_at(i + 2)
          end
        end
      end

      # (getlocal x, a dup or not, setlocal x: the value is there already)
      if e.name == :getlocal
        n = insn_named?(els[i + 1], :dup) ? i + 1 : i
        if insn_named?(els[n + 1], :setlocal) && same_local?(e, els[n + 1])
          els.delete_at(n + 1)
          els.delete_at(n)
          return i if n == i
        end
      end

      # (a block parameter only tested needs no Proc)
      if e.name == :getblockparam && insn_named?(els[i + 1], :branchif, :branchunless)
        e.name = :getblockparamproxy
      end

      # (f(*a, k: 1) and f(*a, k: 1, &b): the keywords' hash is the literal
      #  itself, which the callee may not change -- no KW_SPLAT_MUT)
      if e.name == :splatarray && e.ops[0] == false && insn_named?(els[i + 1], :duphash)
        h = els[i + 1]
        s = nil
        if insn_named?(els[i + 2], :send)
          s = els[i + 2]
          set = CALL_ARGS_SPLAT | CALL_KW_SPLAT | CALL_KW_SPLAT_MUT
          unset = CALL_ARGS_BLOCKARG
        elsif insn_named?(els[i + 2], :getlocal, :getinstancevariable, :getblockparamproxy) &&
              insn_named?(els[i + 3], :send)
          s = els[i + 3]
          set = CALL_ARGS_SPLAT | CALL_KW_SPLAT | CALL_KW_SPLAT_MUT | CALL_ARGS_BLOCKARG
          unset = 0
        end
        if s
          cd = s.ops[0]
          if cd.flag & set == set && cd.flag & unset == 0
            h.name = :putobject
            h.ops = [h.ops[0].dup.freeze]
            s.ops[0] = CallData.new(cd.mid, cd.flag & ~CALL_KW_SPLAT_MUT, cd.argc, cd.kwargs)
          end
        end
      end
      nil
    end

    # (an instruction that only pushes, which a `pop` straight after undoes)
    POP_SILENT = %i[putobject putnil putself putstring putchilledstring dup getlocal
                    getblockparam getblockparamproxy getinstancevariable duparray].freeze

    # compile.c's rules for a branch: one to a jump goes where the jump
    # goes (not past a line event); one on a value known before it runs is
    # a jump or nothing
    def peephole_branch(els, i)
      e = els[i]
      d = dest_index(els, e.ops[0])
      return nil if d.nil? || traces_before(els, d).any? { |t| t.event == :line }
      nobj = els[d]
      pobj = i > 0 && els[i - 1].is_a?(Insn) ? els[i - 1] : nil
      prev_dup = pobj && pobj.name == :dup
      loop do
        if nobj.is_a?(Insn) && nobj.name == :jump
          break if nobj.ops[0].equal?(e.ops[0])
          e.ops[0].refs -= 1
          e.ops[0] = nobj.ops[0]
          e.ops[0].refs += 1
        elsif prev_dup && nobj.is_a?(Insn) && nobj.name == :dup &&
              (nx = els[els.index { |x| x.equal?(nobj) } + 1]).is_a?(Insn) && nx.name == e.name
          break if nx.ops[0].equal?(e.ops[0])
          nobj = nx
          e.ops[0].refs -= 1
          e.ops[0] = nobj.ops[0]
          e.ops[0].refs += 1
        elsif pobj
          pp = pobj
          pp = els[i - 2] if prev_dup && i > 1 && els[i - 2].is_a?(Insn)
          cond = case pp.name
                 when :putobject
                   e.name == :branchif ? pp.ops[0] != false : (e.name == :branchunless ? pp.ops[0] == false : false)
                 when :putstring, :duparray, :newarray then e.name == :branchif
                 when :putnil then e.name != :branchif
                 else break
                 end
          if prev_dup || pp.name != :newarray
            els.delete_at(i - 1)
            i -= 1
          else
            # (iseq_pop_newarray: an empty one goes, a one-element one
            #  leaves its element to a pop, a longer one is adjuststack)
            case pp.ops[0]
            when 0
              els.delete_at(i - 1)
              i -= 1
            when 1 then els[i - 1] = Insn.new(:pop, [], pp.line, pp.node_id, [])
            else pp.name = :adjuststack
            end
          end
          if cond
            if prev_dup
              els.insert(i + 1, Insn.new(:putnil, [], pp.line, pp.node_id, []))
            end
            e.name = :jump
            return :again
          end
          unref(e)
          els.delete_at(i)
          return i
        else
          break
        end
        nd = dest_index(els, nobj.ops[0])
        break unless nd && els[nd].is_a?(Insn)
        nobj = els[nd]
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

    # compile.c's iseq_specialized_instruction: an array built only to be
    # asked max / min / hash / pack / include? is opt_newarray_send, a
    # literal one asked include? opt_duparray_send; a simple send is one of
    # the opt_* the VM answers for the builtin classes, a send with no block
    # opt_send_without_block
    def specialize_insn(els, i)
      e = els[i]
      if e.name == :newarray && (ni = els[i + 1]).is_a?(Insn)
        if ni.name == :send
          cd = ni.ops[0]
          if simple?(cd) && cd.argc == 0 && (m = NEWARRAY_SEND[cd.mid])
            e.name = :opt_newarray_send
            e.ops = [e.ops[0], m]
            els.delete_at(i + 1)
            return
          end
        elsif string_push?(ni) && insn_named?(els[i + 2], :send)
          cd = els[i + 2].ops[0]
          if simple?(cd) && cd.argc == 1 && cd.mid == :pack
            # (it goes after the format, in the send's place)
            e.name = :opt_newarray_send
            e.ops = [e.ops[0] + 1, NEWARRAY_SEND_PACK]
            els.delete_at(i + 2)
            els.delete_at(i)
            els.insert(i + 1, e)
            return
          end
        elsif string_push?(ni) && insn_named?(els[i + 2], :getlocal) && insn_named?(els[i + 3], :send)
          cd = els[i + 3].ops[0]
          if cd.mid == :pack && cd.argc == 2 && cd.kwargs == [:buffer]
            # (after the format and the buffer)
            e.name = :opt_newarray_send
            e.ops = [e.ops[0] + 2, NEWARRAY_SEND_PACK_BUFFER]
            els.delete_at(i + 3)
            els.delete_at(i)
            els.insert(i + 2, e)
            return
          end
        end
        # (include? is looked for apart from those: its argument, then any
        #  simple calls on it without arguments, then the send)
        if insn_named?(ni, :putstring, :putchilledstring, :putobject, :putself, :getlocal, :getinstancevariable) &&
           insn_named?(els[i + 2], :send) && (s = include_send(els, i + 2))
          s.name = :opt_newarray_send
          s.ops = [e.ops[0] + 1, NEWARRAY_SEND_INCLUDE_P]
          els.delete_at(i)
          return
        end
      end
      if e.name == :duparray && insn_named?(els[i + 1], :getlocal, :getinstancevariable, :putself) &&
         insn_named?(els[i + 2], :send) && (s = include_send(els, i + 2))
        s.name = :opt_duparray_send
        s.ops = [e.ops[0], :include?, 1]
        els.delete_at(i)
        return
      end
      return unless e.name == :send
      cd, blk = e.ops
      if simple?(cd)
        sp = case cd.argc
             when 0 then SPECIAL0[cd.mid]
             when 1 then SPECIAL1[cd.mid]
             when 2 then SPECIAL2[cd.mid]
             end
        if sp
          # (insn_set_specialized_instruction: opt_neq carries a calldata
          #  for the == it may ask first; each is a C call to tracing)
          e.name = sp
          e.ops = sp == :opt_neq ? [CallData.new(:==, CALL_ARGS_SIMPLE, 1, nil), cd] : [cd]
          e.events |= [:c_call, :c_return]
          return
        end
      end
      if cd.flag & (CALL_ARGS_BLOCKARG | CALL_FORWARDING) == 0 && blk.nil?
        e.name = :opt_send_without_block
        e.ops = [cd]
      end
    end

    # (the send of a simple include? with one argument, past simple sends
    #  without arguments from k on; nil if there is none)
    def include_send(els, k)
      k += 1 while simple?(cd = els[k].ops[0]) && cd.argc == 0 && insn_named?(els[k + 1], :send)
      cd = els[k].ops[0]
      simple?(cd) && cd.argc == 1 && cd.mid == :include? ? els[k] : nil
    end

    # operand unification (defs/opt_operand.def)
    def unify_insn(e)
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
            # (an instruction the layout makes is of no node: -1)
            lowered << [e, Insn.new(sp - to == 1 ? :pop : :adjuststack, sp - to == 1 ? [] : [sp - to], e.line, -1, [])]
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
      when :opt_send_without_block, :send, :invokesuper, :sendforward, :invokesuperforward
        # (sp_inc_of_sendish: a block argument or the forwarded `...` is
        #  one more)
        [e.ops[0].argc + 1 + (e.ops[0].flag & (CALL_ARGS_BLOCKARG | CALL_FORWARDING) != 0 ? 1 : 0), 1]
      when :splatkw then [2, 2]
      when :pushtoarraykwsplat then [2, 1]
      when :dupn then [e.ops[0], e.ops[0] * 2]
      when :checkkeyword, :getspecial then [0, 1]
      when :definemethod, :jump then [0, 0]
      when :definesmethod then [1, 0]
      when :getblockparam then [0, 1]
      when :setblockparam then [1, 0]
      when :nop then [0, 0]
      when :opt_new then [0, 0]
      when :swap then [2, 2]
      when :setn then [1, 1]
      when :getblockparamproxy then [0, 1]
      when :opt_str_freeze, :opt_str_uminus then [0, 1]
      when :splatarray then [1, 1]
      when :pushtoarray then [e.ops[0] + 1, 1]
      when :expandarray then [1, e.ops[0] + (e.ops[1] & 1)]
      when :concatarray then [2, 1]
      when :concattoarray then [2, 1]
      when :intern then [1, 1]
      when :getinstancevariable, :getglobal, :opt_getconstant_path, :putspecialobject, :duphash, :invokeblock_dummy then [0, 1]
      when :setinstancevariable, :setglobal then [1, 0]
      when :setconstant then [2, 0]
      when :getconstant then [2, 1]
      when :defined then [1, 1]
      when :definedivar then [0, 1]
      when :throw then [1, 1]
      when :objtostring, :anytostring then [e.name == :anytostring ? 2 : 1, 1]
      when :concatstrings, :newhash then [e.ops[0], 1]
      when :newrange then [2, 1]
      when :invokeblock then [e.ops[0].argc, 1]
      when :defineclass then [2, 1]
      when :adjuststack then [e.ops[0], 0]
      when :topn then [0, 1]
      when :opt_case_dispatch, :branchnil then [1, 0]
      when :checkmatch then [2, 1]
      when :opt_ary_freeze, :opt_hash_freeze then [0, 1]
      when :opt_newarray_send then [e.ops[0], 1]
      when :opt_duparray_send then [e.ops[2], 1]
      when :opt_reverse then [e.ops[0], e.ops[0]]
      else
        e.name.to_s.start_with?("opt_") ? [e.ops[0].argc + 1, 1] : [0, 0]
      end
    end

    # -- to_a ----------------------------------------------------------------
    def to_a(u)
      misc = { arg_size: arg_size(u), local_size: u.locals.size, stack_max: u.stack_max,
               node_id: u.node_id, code_location: u.code_location,
               node_ids: u.elements.grep(Insn).map(&:node_id), parser: u.parser }
      # (iseq_data_to_ary's labels_table: a position some operand, the opt
      #  table, a cdhash or a catch entry names, shown before the
      #  instruction there)
      named = {}
      (u.params[:opt] || []).each { |l| named[l.pos] = true }
      exception = u.kept_catch.map do |c|
        st, ed, cont, sp = catch_positions(c)
        [st, ed, cont].each { |x| named[x] = true }
        [c[0], c[3] && to_a(c[3]), :"label_#{st}", :"label_#{ed}", :"label_#{cont}", sp]
      end
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        e.ops.each do |o|
          named[o.pos] = true if o.is_a?(Label)
          o.entries.each { |_, l| named[l.pos] = true } if o.is_a?(CDHash)
        end
      end
      body = []
      last = nil
      pos = 0
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        body << :"label_#{pos}" if named[pos]
        pos += 1 + e.ops.size
        if e.line > 0 && e.line != last
          body << e.line
          last = e.line
        end
        EVENT_DISASM.each { |ev, _| body << EVENT_TO_A[ev] if e.events.include?(ev) && EVENT_TO_A[ev] }
        body << [e.name, *e.ops.map { |o| operand_to_a(o) }]
      end
      pr = u.params
      params = {}
      params[:opt] = pr[:opt].map { |l| :"label_#{l.pos}" } if pr[:opt]
      # (a for loop's block counts its hidden parameter without has_lead)
      params[:lead_num] = pr[:lead_num] if pr[:lead_num] > 0 && !pr[:for]
      if pr[:post_num]
        params[:post_num] = pr[:post_num]
        params[:post_start] = pr[:post_start]
      end
      params[:rest_start] = pr[:rest_start] if pr[:rest_start]
      params[:block_start] = pr[:block_start] if pr[:block_start]
      if pr[:keyword]
        params[:kwbits] = pr[:kwbits]
        params[:keyword] = pr[:keyword]
      end
      params[:kwrest] = pr[:kwrest] if pr[:kwrest]
      params[:ambiguous_param0] = true if pr[:ambiguous_param0]
      params[:use_block] = true if pr[:use_block]
      # (a hidden local -- kwbits -- is numbered as iseq_data_to_ary numbers it)
      locals = u.locals.each_with_index.map { |l, i| l.is_a?(Integer) ? u.locals.size - i + 1 : l }
      ["YARVInstructionSequence/SimpleDataFormat", 4, 0, 1, misc, u.label, u.path, u.abs_path || u.path,
       u.first_lineno, u.type, locals, params, exception, body]
    end

    def operand_to_a(o)
      case o
      when CallData
        h = { mid: o.mid, flag: o.flag }
        h[:kw_arg] = o.kwargs if o.kwargs
        h[:orig_argc] = o.argc - (o.kwargs ? o.kwargs.size : 0)
        h
      when Label then :"label_#{o.pos}"
      when LocalOp then o.idx
      when IVC then o.index
      when IC then o.segments
      when DefType then o.n
      when CDHash then o.entries.flat_map { |k, l| [k, :"label_#{l.pos}"] }
      when Unit then to_a(o)
      else o
      end
    end

    # iseq_iterate_children: the catch table's sequences, then the ones the
    # instructions name, in their order, each once (one an unreachable chunk
    # took is not among them)
    def children(u)
      seen = {}.compare_by_identity
      u.kept_catch.each { |c| seen[c[3]] = true if c[3] }
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        e.ops.each { |o| seen[o] = true if o.is_a?(Unit) }
      end
      seen.keys
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
        out << [e.line, :rescue] if ev.include?(:rescue)
      end
      out
    end

    def arg_size(u)
      pr = u.params
      n = pr[:lead_num] + (pr[:opt] ? pr[:opt].size - 1 : 0) + (pr[:rest_start] ? 1 : 0) + (pr[:post_num] || 0)
      n += pr[:keyword].size + 1 if pr[:keyword]
      n += 1 if pr[:kwrest]
      n += 1 if pr[:block_start]
      # (a forwardable method's `...` is passed as a parameter)
      n += 1 if pr[:forwardable]
      n
    end

    # -- disasm --------------------------------------------------------------
    INSN_NAME_WIDTH = 38

    CATCH_RULE = "|" + "-" * 72

    def disasm(u, indent = "")
      out = +""
      # (iseq.c pads a short header with '=' -- by a memset past the
      #  string's end, which never shows: the header is printed as is)
      out << indent << "== disasm: #{inspect_unit(u)}" << "\n"
      # (the catch table, each entry's sequence under it one "| " deeper;
      #  those are not shown again with the children)
      done = {}.compare_by_identity
      unless u.kept_catch.empty?
        out << indent << "== catch table\n"
        u.kept_catch.each do |c|
          st, ed, cont, sp = catch_positions(c)
          out << indent << format("| catch type: %-6s st: %04d ed: %04d sp: %04d cont: %04d\n", c[0], st, ed, sp, cont)
          if c[3] && !done[c[3]]
            out << disasm(c[3], indent + "| ")
            done[c[3]] = true
          end
        end
        out << indent << CATCH_RULE << "\n"
      end
      unless u.locals.empty?
        pr = u.params
        out << indent << format("local table (size: %d, argc: %d [opts: %d, rest: %d, post: %d, block: %d, kw: %d@%d, kwrest: %d])\n",
                      u.locals.size, pr[:lead_num], pr[:opt] ? pr[:opt].size - 1 : 0, pr[:rest_start] || -1,
                      pr[:post_num] || 0, pr[:block_start] || -1, pr[:keyword] ? pr[:keyword].size : -1,
                      pr[:keyword] ? pr[:kw_required] : -1, pr[:kwrest] || -1)
        line = +""
        n = u.locals.size
        u.locals.each_with_index do |name, li|
          i = n - li - 1
          entry = format("[%2d] ", i + 1)
          line << indent
          width = line.size + entry.size + 11
          shown = local_name(name)
          line << entry << "#{shown}@#{li}"
          pr = u.params
          argi = +""
          argi << (pr[:ambiguous_param0] ? "AmbiguousArg" : "Arg") if li < pr[:lead_num]
          if pr[:opt] && li >= pr[:lead_num] && li < pr[:lead_num] + pr[:opt].size - 1
            argi << "Opt=#{pr[:opt][li - pr[:lead_num]].pos}"
          end
          argi << (pr[:anon_rest] ? "AnonRest" : "Rest") if pr[:rest_start] == li
          argi << "Post" if pr[:post_start] && li >= pr[:post_start] && li < pr[:post_start] + pr[:post_num]
          argi << (pr[:anon_kwrest] ? "AnonKwrest" : "Kwrest") if pr[:kwrest] == li
          argi << "Block" if pr[:block_start] == li
          line << "<#{argi}>" unless argi.empty?
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
        if e.line && e.line > 0 && e.line != prev_line
          slen = s.size > 70 ? 0 : 70 - s.size
          s << " " * slen << format("(%4d)", e.line)
        end
        prev_line = e.line
        ev = e.events
        unless ev.empty?
          s << "[" << EVENT_DISASM.select { |k, _| ev.include?(k) }.map(&:last).join << "]"
        end
        out << indent << s.rstrip << "\n"
        pos += 1 + e.ops.size
      end
      # (the children an instruction names, in the order they are named)
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        e.ops.each { |o| out << "\n" << disasm(o, indent) if o.is_a?(Unit) && !done[o] }
      end
      out
    end

    # iseq_set_exception_table: positions of the entry's labels, and the
    # stack depth at its continuation (one less for rescue, break, next)
    def catch_positions(c)
      t, ls, le, _, lc = c
      sp = lc ? (lc.sp || 0) : 0
      sp -= 1 if %i[rescue break next].include?(t) && sp > 0
      [ls.pos, le.pos, lc ? lc.pos : 0, sp]
    end

    # (a hidden local is "?", one that is no plain identifier is quoted)
    def local_name(name)
      return "?" if name.is_a?(Integer)
      name.to_s.match?(/\A[a-z_][A-Za-z0-9_]*\z/) ? name.to_s : name.to_s.inspect
    end

    def inspect_unit(u)
      cl = u.code_location
      # (iseq_inspect: the line is the code location's, not first_lineno)
      "#<ISeq:#{u.label}@#{u.path}:#{cl[0]} (#{cl[0]},#{cl[1]})-(#{cl[2]},#{cl[3]})>"
    end

    def operand_disasm(o)
      case o
      when CallData
        flags = CALL_FLAG_NAMES.select { |b, _| o.flag & b != 0 }.map(&:last)
        "<calldata!#{o.mid ? "mid:#{o.mid}, " : ""}argc:#{o.argc}#{o.kwargs ? ", kw:[#{o.kwargs.join(",")}]" : ""}#{flags.empty? ? "" : ", " + flags.join("|")}>"
      when IVC then "<is:#{o.index}>"
      when IC then "<ic:#{o.index + (o.base || 0)} #{o.segments.join("::")}>"
      when DefType then DEFINED_NAMES[o.n]
      when CDHash then "<cdhash>"
      when Label then o.pos.to_s
      when LocalOp then "#{local_name(o.name)}@#{o.index}"
      when Unit then o.label
      when Symbol then o.inspect
      when nil then "nil"
      else o.inspect
      end
    end
  end
end
