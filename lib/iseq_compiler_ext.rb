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
    # (is_entries holds the ivar caches first and the constant caches after
    #  them: an IC's place there, which disasm shows, is past every IVC)
    IC = Struct.new(:index, :segments, :base)
    CallData = Struct.new(:mid, :flag, :argc, :kwargs)
    # (opt_case_dispatch's hash: the first `when` of a key wins; its labels
    #  are not counted as references, as compile.c's TS_CDHASH is not)
    CDHash = Struct.new(:entries)

    # rb_compile_option_t's defaults (the ones ISeq.compile_option shows)
    DEFAULT_OPTIONS = { inline_const_cache: true, peephole_optimization: true, tailcall_optimization: false,
                        specialized_instruction: true, operands_unification: true,
                        instructions_unification: false, frozen_string_literal: false }.freeze

    # one instruction sequence being built, and what to_a / disasm read off it
    class Unit
      attr_reader :type, :label, :path, :abs_path, :first_lineno, :locals, :params,
                  :children, :elements, :code_location, :node_id, :parent
      attr_accessor :stack_max
      attr_writer :opts
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
      def adjust(l, restore = true) = @elements << Adjust.new(l, @line, @node, restore)
      def next_is = (@is_n = (@is_n || -1) + 1)
      def next_ic = (@ic_n = (@ic_n || -1) + 1)
      def ivc_size = (@is_n || -1) + 1
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
        unless popped
          ref = local_ref(u, n.name, n.depth)
          lv, owner = u.level_of(n.name)
          if owner.params[:block_start] && owner.locals[owner.params[:block_start]] == n.name
            u.insn(:getblockparam, *ref)
          else
            u.insn(:getlocal, *ref)
          end
        end
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
        unless u.opts[:inline_const_cache]
          # (pm_compile_constant_read without the cache: getconstant)
          raise NotImplementedError, "RubyVM::InstructionSequence: a constant path without inline_const_cache is not compiled yet" unless n.is_a?(Prism::ConstantReadNode)
          u.insn(:putnil)
          u.insn(:putobject, true)
          u.insn(:getconstant, n.name)
          u.insn(:pop) if popped
          return
        end
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
      when Prism::SourceFileNode
        u.insn(:putchilledstring, u.path.dup.freeze) unless popped
      when Prism::SourceLineNode
        u.insn(:putobject, n.location.start_line) unless popped
      when Prism::RegularExpressionNode
        u.insn(:putobject, Regexp.new(n.unescaped, n.options & 7)) unless popped
      when Prism::BeginNode
        if n.rescue_clause || n.ensure_clause || n.else_clause
          raise NotImplementedError, "RubyVM::InstructionSequence: begin with rescue / else / ensure is not compiled yet"
        end
        if n.statements then node(u, n.statements, popped) else (u.insn(:putnil) unless popped) end
      when Prism::NextNode then next_node(u, n)
      when Prism::InterpolatedSymbolNode
        dstr(u, n, false)
        here(u, n)
        u.insn(:intern)
        u.insn(:pop) if popped
      when Prism::ElseNode then compile_part(u, n, popped, nil)
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
          raise NotImplementedError, "RubyVM::InstructionSequence: an anonymous splat is not compiled yet" unless e.expression
          node(u, e.expression, false)
          here(u, n)
          if first then (u.insn(:splatarray, true); first = false) else u.insn(:concattoarray) end
          static_run = false
        elsif e.is_a?(Prism::KeywordHashNode)
          raise NotImplementedError, "RubyVM::InstructionSequence: keywords in an array are not compiled yet"
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
    def call(u, n, popped)
      line = (n.message_loc || n.location).start_line
      at = -> { u.at(line, n.node_id) }
      if (n.name == :-@ || n.name == :freeze) && n.receiver.is_a?(Prism::StringNode) && !n.safe_navigation? &&
         n.arguments.nil? && n.block.nil? && u.opts[:specialized_instruction]
        at.()
        u.insn(n.name == :freeze ? :opt_str_freeze : :opt_str_uminus, n.receiver.unescaped.dup.freeze,
               CallData.new(n.name, CALL_ARGS_SIMPLE, 0, nil))
        u.insn(:pop) if popped
        return
      end
      write = n.attribute_write? && !popped
      at.()
      u.insn(:putnil) if write
      flag = 0
      r = n.receiver
      if r.nil?
        at.()
        u.insn(:putself)
      elsif n.name == :call && r.is_a?(Prism::LocalVariableReadNode) && block_param?(u, r.name)
        u.at(line, r.node_id)
        u.insn(:getblockparamproxy, *local_ref(u, r.name, r.depth))
      else
        node(u, r, false)
      end
      flag |= CALL_FCALL if r.nil? || n.ignore_visibility?
      else_l = end_l = nil
      if n.safe_navigation?
        else_l = u.new_label
        end_l = u.new_label
        at.()
        u.insn(:dup)
        u.insn(:branchnil, else_l)
      end
      prelude = u.elements.size
      argc, aflag, kws = setup_args(u, n.arguments ? n.arguments.arguments : [], n.block, n)
      flag |= aflag
      flag |= CALL_VCALL if n.variable_call?
      flag |= CALL_ARGS_SIMPLE if (flag & (CALL_ARGS_SPLAT | CALL_ARGS_BLOCKARG | CALL_KWARG | CALL_KW_SPLAT)) == 0 &&
                                  !n.block.is_a?(Prism::BlockNode)
      blk = n.block.is_a?(Prism::BlockNode) ? block_unit(u, n.block) : nil
      at.()
      if write
        if flag & (CALL_ARGS_BLOCKARG | CALL_ARGS_SPLAT) != 0
          raise NotImplementedError, "RubyVM::InstructionSequence: an attribute write with a splat or a block argument is not compiled yet"
        end
        u.insn(:setn, argc + 1)
      end
      if u.opts[:specialized_instruction] && n.name == :new && n.block.nil?
        pair = [Insn.new(:putnil, [], line, n.node_id, []), Insn.new(:swap, [], line, n.node_id, [])]
        if u.elements.size == prelude then u.elements.concat(pair) else u.elements.insert(prelude, *pair) end
        not_basic = u.new_label
        done = u.new_label
        u.insn(:opt_new, CallData.new(:new, flag, argc, kws), not_basic)
        u.insn(:send, CallData.new(:initialize, flag | CALL_FCALL, argc, kws), nil)
        u.insn(:jump, done)
        u.emit_label(not_basic)
        u.insn(:send, CallData.new(:new, flag, argc, kws), nil)
        u.insn(:swap)
        u.emit_label(done)
        u.insn(:pop)
      else
        u.insn(:send, CallData.new(n.name, flag, argc, kws), blk)
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
      retry_end = u.new_label
      retry_end.unremovable = true
      node(u, n.collection, false)
      method_unit = u
      method_unit = method_unit.parent while method_unit.type == :block
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
      child.insn(:nop)
      compile_body(child, n.statements, n.node_id, l.end_line)
      finish(child)
      here(u, n)
      u.insn(:send, CallData.new(:each, 0, 0, nil), child)
      u.emit_label(retry_end)
      u.insn(:pop) if popped
    end

    # make_name_for_block: one, and one more for each block from the scope
    # the block is in up to its method's
    def block_levels(u) = u.type == :block ? u.depth + 2 : 1

    def block_param?(u, name)
      _, owner = u.level_of(name)
      owner && owner.params[:block_start] && owner.locals[owner.params[:block_start]] == name
    end

    # pm_setup_args, for the shapes compiled so far: plain arguments, one
    # splat (`splatarray false` when it is last, otherwise the array built
    # on with pushtoarray -- ARGS_SPLAT_MUT), keyword arguments with symbol
    # keys (KWARG), and a block argument (ARGS_BLOCKARG)
    def setup_args(u, args, block, owner)
      flag = 0
      kws = nil
      args = args.dup
      kwh = args.last.is_a?(Prism::KeywordHashNode) ? args.pop : nil
      si = args.index { |a| a.is_a?(Prism::SplatNode) }
      if si
        raise NotImplementedError, "RubyVM::InstructionSequence: two splats are not compiled yet" if args.count { |a| a.is_a?(Prism::SplatNode) } > 1
        raise NotImplementedError, "RubyVM::InstructionSequence: a splat with keywords is not compiled yet" if kwh
        args[0...si].each { |a| node(u, a, false) }
        sp = args[si]
        post = args[(si + 1)..]
        raise NotImplementedError, "RubyVM::InstructionSequence: an anonymous splat is not compiled yet" unless sp.expression
        node(u, sp.expression, false)
        here(u, owner)
        if post.empty?
          u.insn(:splatarray, false)
          flag |= CALL_ARGS_SPLAT
        else
          u.insn(:splatarray, true) unless sp.expression.is_a?(Prism::ArrayNode)
          post.each { |a| node(u, a, false) }
          here(u, owner)
          u.insn(:pushtoarray, post.size)
          flag |= CALL_ARGS_SPLAT | CALL_ARGS_SPLAT_MUT
        end
        argc = si + 1
      else
        args.each { |a| node(u, a, false) }
        argc = args.size
      end
      if kwh
        unless kwh.elements.all? { |e| e.is_a?(Prism::AssocNode) && e.key.is_a?(Prism::SymbolNode) }
          raise NotImplementedError, "RubyVM::InstructionSequence: these keyword arguments are not compiled yet"
        end
        kws = kwh.elements.map { |e| e.key.unescaped.to_sym }
        kwh.elements.each { |e| node(u, e.value, false) }
        argc += kws.size
        flag |= CALL_KWARG
      end
      if block.is_a?(Prism::BlockArgumentNode)
        raise NotImplementedError, "RubyVM::InstructionSequence: an anonymous block argument is not compiled yet" unless block.expression
        node(u, block.expression, false)
        flag |= CALL_ARGS_BLOCKARG
      end
      [argc, flag, kws]
    end

    def block_unit(u, b)
      method_unit = u
      method_unit = method_unit.parent while method_unit.type == :block
      levels = block_levels(u)
      label = levels == 1 ? "block in #{method_unit.label}" : "block (#{levels} levels) in #{method_unit.label}"
      l = b.location
      child = Unit.new(:block, label, u.path, u.abs_path, l.start_line, b.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], b.node_id)
      params(child, b.parameters.is_a?(Prism::BlockParametersNode) ? b.parameters.parameters : nil, b.parameters)
      u.children << child
      opt_defaults(child)
      child.at(l.start_line, b.node_id)
      child.event(:b_call)
      # (after optional defaults the b_call is a nop's of its own)
      child.insn(:nop) if child.params[:opt]
      compile_body(child, b.body.is_a?(Prism::StatementsNode) ? b.body : nil, b.node_id, l.end_line)
      finish(child)
      child
    end

    # The parameters, as ruby lays them out in the local table: lead, opt,
    # rest, post, keywords, the hidden kwbits slot, kwrest, block, then the
    # body's own locals. (a block's one required parameter with no
    # optional, rest, post or keyword one -- `|y|`, `|y, &b|`, not `|y,|` --
    # is ambiguous_param0: the block takes an Array's first element or the
    # whole value, as yield passes it.)
    def params(unit, ps, owner)
      return unless ps
      if ps.requireds.any? { |r| !r.is_a?(Prism::RequiredParameterNode) } ||
         ps.posts.any? { |r| !r.is_a?(Prism::RequiredParameterNode) } ||
         ps.keyword_rest.is_a?(Prism::ForwardingParameterNode)
        raise NotImplementedError, "RubyVM::InstructionSequence: these parameters are not compiled yet"
      end
      pr = unit.params
      names = []
      ps.requireds.each { |r| names << r.name }
      pr[:lead_num] = ps.requireds.size
      unless ps.optionals.empty?
        pr[:opt_nodes] = ps.optionals
        ps.optionals.each { |o| names << o.name }
      end
      if ps.rest && !ps.rest.is_a?(Prism::ImplicitRestNode)
        pr[:rest_start] = names.size
        pr[:anon_rest] = ps.rest.name.nil?
        names << (ps.rest.name || :*)
      end
      unless ps.posts.empty?
        pr[:post_start] = names.size
        pr[:post_num] = ps.posts.size
        ps.posts.each { |r| names << r.name }
      end
      unless ps.keywords.empty?
        kw = ps.keywords.map do |k|
          if k.is_a?(Prism::RequiredKeywordParameterNode) then k.name
          elsif static_literal?(k.value) then [k.name, static_value(k.value)]
          else raise NotImplementedError, "RubyVM::InstructionSequence: a keyword default that is not a literal is not compiled yet"
          end
        end
        # (required ones first, as ruby keeps them)
        req = kw.select { |k| k.is_a?(Symbol) }
        opt = kw.reject { |k| k.is_a?(Symbol) }
        pr[:keyword] = req + opt
        pr[:kw_required] = req.size
        (req + opt.map(&:first)).each { |k| names << k }
        pr[:kwbits] = names.size
        names << names.size
      end
      if ps.keyword_rest.is_a?(Prism::NoKeywordsParameterNode)
        # (**nil: accepts_no_kwarg, which neither to_a nor disasm shows)
        pr[:no_kwarg] = true
      elsif ps.keyword_rest
        pr[:kwrest] = names.size
        pr[:anon_kwrest] = ps.keyword_rest.name.nil?
        names << (ps.keyword_rest.name || :**)
      end
      if ps.block
        pr[:block_start] = names.size
        names << (ps.block.name || :&)
        pr[:use_block] = true
      end
      rest_locals = unit.locals.reject { |l| names.include?(l) }
      unit.locals.replace(names + rest_locals)
      # (ruby asks before it counts **kw and &b: only one local so far)
      if unit.type == :block && ps.requireds.size == 1 && ps.rest.nil? && ps.optionals.empty? && ps.posts.empty? &&
         ps.keywords.empty?
        pr[:ambiguous_param0] = true
      end
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

    def define(u, n, popped)
      l = n.location
      child = Unit.new(:method, n.name.to_s, u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
      params(child, n.parameters, nil)
      u.children << child
      body = n.body
      first = body.is_a?(Prism::StatementsNode) ? body.body.first : nil
      opt_defaults(child)
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
    # (at the top level the scope itself is as a method; from a block ruby
    #  throws TAG_RETURN, which needs the catch table)
    def return_node(u, n, popped)
      unless u.type == :method || u.type == :top
        raise NotImplementedError, "RubyVM::InstructionSequence: return from a block is not compiled yet"
      end
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

    # class << x: a class sequence "singleton class", defineclass with
    # the singleton flag
    def singleton_class(u, n, popped)
      l = n.location
      child = Unit.new(:class, "singleton class", u.path, u.abs_path, l.start_line, n.locals, u,
                       [l.start_line, l.start_column, l.end_line, l.end_column], n.node_id)
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
           Prism::StringNode, Prism::SymbolNode, Prism::TrueNode
        here(u, at)
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

    # (a `next` in a loop: its value, the stack back to the loop's -- an
    #  ADJUST to the redo label -- and the condition again)
    def next_node(u, n)
      lp = u.loops.last or raise NotImplementedError, "RubyVM::InstructionSequence: next in a block is not compiled yet"
      args = n.arguments&.arguments || []
      raise NotImplementedError, "RubyVM::InstructionSequence: next with values" if args.size > 1
      if args.empty? then (here(u, n); u.insn(:putnil)) else node(u, args[0], false) end
      here(u, n)
      u.adjust(lp[2], false)
      u.insn(:jump, lp[0])
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
      u.elements.each { |e| e.ops.each { |o| o.base = u.ivc_size if o.is_a?(IC) } if e.is_a?(Insn) }
      peephole(u) if u.opts[:peephole_optimization]
      specialize(u) if u.opts[:specialized_instruction]
      unify(u) if u.opts[:operands_unification]
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
          # (a rule that took out what came before: go on from there)
          if changed.is_a?(Integer)
            i = changed
            next
          end
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
          # (it takes the leave's insn_info, the events
          #  get_destination_insn gave it included)
          unref(e)
          e.name = :leave
          e.ops = []
          e.line, e.node_id = de.line, de.node_id
          tr = traces_before(els, d).reverse.map { |t| Trace.new(t.event) }
          els.insert(i, *tr)
          return i + tr.size
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
      when :branchif, :branchunless, :branchnil
        return peephole_branch(els, i)
      when :newarray, :duparray, :concatarray, :splatarray
        # (an instruction that always pushes an array needs no splatarray)
        els.delete_at(i + 1) if els[i + 1].is_a?(Insn) && els[i + 1].name == :splatarray
      when :pop
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
            return i
          else
            pe.name = :adjuststack
            els.delete_at(i)
            return i
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
                 when :putstring, :duparray then e.name == :branchif
                 when :putnil then e.name != :branchif
                 when :newarray
                   raise NotImplementedError, "RubyVM::InstructionSequence: a branch on a new array is not compiled yet"
                 else break
                 end
          els.delete_at(i - 1)
          i -= 1
          if cond
            if prev_dup
              els.insert(i + 1, Insn.new(:putnil, [], pp.line, pp.node_id, []))
            end
            e.name = :jump
            return i
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

    # a send with no block and plain arguments is opt_send_without_block,
    # or one of the opt_* the VM answers for the builtin classes
    def specialize(u)
      u.elements.each do |e|
        next unless e.is_a?(Insn) && e.name == :send && e.ops[1].nil?
        cd = e.ops[0]
        next if cd.flag & CALL_ARGS_BLOCKARG != 0
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
      when :opt_send_without_block, :send
        [e.ops[0].argc + 1 + (e.ops[0].flag & CALL_ARGS_BLOCKARG != 0 ? 1 : 0), 1]
      when :definemethod, :jump then [0, 0]
      when :definesmethod then [1, 0]
      when :getblockparam then [0, 1]
      when :nop then [0, 0]
      when :opt_new then [0, 0]
      when :swap then [2, 2]
      when :setn then [1, 1]
      when :getblockparamproxy then [0, 1]
      when :opt_str_freeze, :opt_str_uminus then [0, 1]
      when :splatarray then [1, 1]
      when :pushtoarray then [e.ops[0] + 1, 1]
      when :concattoarray then [2, 1]
      when :intern then [1, 1]
      when :getinstancevariable, :getglobal, :opt_getconstant_path, :putspecialobject, :duphash, :invokeblock_dummy then [0, 1]
      when :setinstancevariable, :setglobal then [1, 0]
      when :setconstant then [2, 0]
      when :getconstant then [2, 1]
      when :objtostring, :anytostring then [e.name == :anytostring ? 2 : 1, 1]
      when :concatstrings, :newhash then [e.ops[0], 1]
      when :newrange then [2, 1]
      when :invokeblock then [e.ops[0].argc, 1]
      when :defineclass then [2, 1]
      when :adjuststack then [e.ops[0], 0]
      when :topn then [0, 1]
      when :opt_case_dispatch, :branchnil then [1, 0]
      when :checkmatch then [2, 1]
      else
        e.name.to_s.start_with?("opt_") ? [e.ops[0].argc + 1, 1] : [0, 0]
      end
    end

    # -- to_a ----------------------------------------------------------------
    def to_a(u)
      misc = { arg_size: arg_size(u), local_size: u.locals.size, stack_max: u.stack_max,
               node_id: u.node_id, code_location: u.code_location,
               node_ids: u.elements.grep(Insn).map(&:node_id), parser: :prism }
      # (iseq_data_to_ary's labels_table: a position some operand, the opt
      #  table, a cdhash or a catch entry names, shown before the
      #  instruction there)
      named = {}
      (u.params[:opt] || []).each { |l| named[l.pos] = true }
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
        if e.line != last
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
       u.first_lineno, u.type, locals, params, [], body]
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
      when CDHash then o.entries.flat_map { |k, l| [k, :"label_#{l.pos}"] }
      when Unit then to_a(o)
      else o
      end
    end

    # iseq_iterate_children: the sequences the instructions name, in their
    # order, each once (one an unreachable chunk took is not among them)
    def children(u)
      seen = {}.compare_by_identity
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
      end
      out
    end

    def arg_size(u)
      pr = u.params
      n = pr[:lead_num] + (pr[:opt] ? pr[:opt].size - 1 : 0) + (pr[:rest_start] ? 1 : 0) + (pr[:post_num] || 0)
      n += pr[:keyword].size + 1 if pr[:keyword]
      n += 1 if pr[:kwrest]
      n += 1 if pr[:block_start]
      n
    end

    # -- disasm --------------------------------------------------------------
    INSN_NAME_WIDTH = 38

    def disasm(u)
      out = +""
      # (iseq.c pads a short header with '=' -- by a memset past the
      #  string's end, which never shows: the header is printed as is)
      out << "== disasm: #{inspect_unit(u)}" << "\n"
      unless u.locals.empty?
        pr = u.params
        out << format("local table (size: %d, argc: %d [opts: %d, rest: %d, post: %d, block: %d, kw: %d@%d, kwrest: %d])\n",
                      u.locals.size, pr[:lead_num], pr[:opt] ? pr[:opt].size - 1 : 0, pr[:rest_start] || -1,
                      pr[:post_num] || 0, pr[:block_start] || -1, pr[:keyword] ? pr[:keyword].size : -1,
                      pr[:keyword] ? pr[:kw_required] : -1, pr[:kwrest] || -1)
        line = +""
        n = u.locals.size
        u.locals.each_with_index do |name, li|
          i = n - li - 1
          entry = format("[%2d] ", i + 1)
          width = line.size + entry.size + 11
          shown = name.is_a?(Integer) ? "?" : (name.to_s.match?(/\A[a-z_][A-Za-z0-9_]*\z/) ? name.to_s : name.to_s.inspect)
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
      # (the children an instruction names, in the order they are named)
      u.elements.each do |e|
        next unless e.is_a?(Insn)
        e.ops.each { |o| out << "\n" << disasm(o) if o.is_a?(Unit) }
      end
      out
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
      when CDHash then "<cdhash>"
      when Label then o.pos.to_s
      when LocalOp then "#{o.name.is_a?(Integer) ? "?" : o.name}@#{o.index}"
      when Unit then o.label
      when Symbol then o.inspect
      when nil then "nil"
      else o.inspect
      end
    end
  end
end
