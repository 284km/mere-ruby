# Round 38 of note 552: a whole FILE on the ISeq VM. A child is run twice on
# one script -- as it is, and with MERE_RUBY_VM=strict, which runs the main
# script and every file it requires on the VM and raises where the compiler
# or the VM would not take one (ruby ignores the variable) -- and the two
# runs print the same lines, ruby's. The script is what the corpus's own run
# on the VM found: parameters named `_` twice, a lone `**` argument and
# splatkw's order, a def under instance_eval of a value with no singleton
# class, the frame's line under a rescue clause, a break in a Thread's body,
# the unused-block and reassigned-constant warnings, a TracePoint's binding
# of a frame, an interpolated pattern's pieces, a shareable Proc's outer
# locals, a builtin operator's own frame, literals made without the
# program's Regexp.new and frozen.
require "rbconfig"
require "tmpdir"

MAIN = <<~'RUBY'
  require_relative "side663"
  def t(label)
    r = yield
    puts "#{label}: #{r.inspect}"
  rescue Exception => e
    puts "#{label}: #{e.class}: #{e.message}"
  end

  # a second `_` is a parameter of its own; the first is what `_` reads
  def y2(a, b) = yield(a, b)
  t("underscores") { [y2(1, 2) { |_, _| _ }, proc { |_, _ = 1, _:, _: 2| }.parameters] }

  # `**obj` converts with #to_hash, before the block's #to_proc; `**nil` and
  # `**{}` pass nothing but still say keywords were given
  class NoHash663; end
  def kw(*a, **k) = [a, k]
  pr = proc { |x, y = 0| [x, y] }
  t("double splat") { kw(**NoHash663.new) }
  t("empty splats") { [kw(**nil), kw(1, **{}), pr.call([1, 2, 3], **{}), pr.call([1, 2, 3])] }
  order = []
  o = Object.new
  o.define_singleton_method(:to_hash) { order << :to_hash; {} }
  o.define_singleton_method(:to_proc) { order << :to_proc; -> {} }
  t("splat order") { kw(**o, &o); order }

  # a def, an undef and an alias run where there is no singleton class: the
  # TypeError is theirs, when they run -- a constant or a class is not refused
  t("def on 1") { 1.instance_eval { def none663 = 1 } }
  t("undef on 1") { 1.instance_eval { undef to_s } }
  t("const on 1") { 1.instance_eval { C663 = 1 }; C663 }
  t("untaken def") { 1.instance_eval { if false then def never663 = 1 end; :ok } }

  # under a rescue clause the frame is seen at its def's / begin's line
  # (the two methods are in the side file)
  t("rescue frames") { [def_level663, begin_level663] }

  # a break in a Thread's body that no loop takes
  t("thread break") do
    Thread.new do
      begin
        break :brk
      rescue LocalJumpError => e
        [e.class, e.reason, e.exit_value]
      end
    end.value
  end
  t("thread loop") { Thread.new { i = 0; while true; i += 1; break if i > 2; end; i }.value }

  # warnings: a block given to a method that takes none, a constant again
  warned = []
  Warning.singleton_class.define_method(:warn) { |m, **| warned << m.sub(/\A.*?warning: /, "").sub(/ defined at .*? may/, " defined at ... may").chomp }
  $VERBOSE = true
  def unused663 = 42
  def yields663 = yield
  unused663 { }
  yields663 { }
  Again663 = 1
  class Holder663; ::Again663 = 2; end
  $VERBOSE = false
  t("warnings") { warned.map { |w| w.sub(/\A.*: /, "") } }

  # a TracePoint's binding sees the frame's locals, assigned yet or not
  class Traced663
    def run(n)
      k = n * 2
      k + 1
    end
  end
  seen = []
  tp = TracePoint.new(:call, :line, :return) do |tr|
    next unless tr.defined_class == Traced663
    seen << [tr.event, tr.binding.local_variable_defined?(:k), tr.binding.eval("k")]
  end
  tp.enable { Traced663.new.run(3) }
  t("binding") { seen }

  # each computed piece of a pattern is read on its own, in its encoding
  t("pattern pieces") { s1 = '\xc2'.dup.force_encoding("EUC-JP"); s2 = '\xa1'.dup.force_encoding("EUC-JP"); /#{s1}#{s2}/ }

  # a shareable Proc refuses an outer local that is assigned again
  w = 1
  t("reassigned outer") { Ractor.shareable_proc { w } }
  w = 2
  once = 3
  t("single outer") { Ractor.shareable_proc { once }.call }

  # a builtin operator is a frame of what it refuses
  t("operator frame") { begin; 1 + nil; rescue TypeError => e; e.backtrace_locations.map(&:label); end }
  # a literal is the source's own: no Regexp.new or Range.new of the
  # program's is called for one (the file is compiled when it is required,
  # after these two are defined), and a Regexp literal is frozen
  def Regexp.new(*) = :intercepted
  def Range.new(*) = :intercepted
  require_relative "lits663"
  t("side file") { [Side663.where, Side663.new.each_pair.to_a, File.basename(__dir__) == File.basename(File.dirname(__FILE__))] }
RUBY

SIDE = <<~'RUBY'
  def def_level663
    raise
  rescue
    caller_locations(1, 1)[0].lineno - __LINE__
  end
  def begin_level663
    x = 0
    begin
      raise
    rescue
      caller_locations(1, 1)[0].lineno - __LINE__
    end
  end
  class Side663
    def self.where = File.basename(__FILE__)
    def initialize = @h = { a: 1, b: 2 }
    def each_pair
      return to_enum(:each_pair) unless block_given?
      @h.each_pair { |k, v| yield k, v }
    end
  end
RUBY

LITS = <<~'RUBY'
  t("literals") { [/abc/.class, /a#{1}c/.class, (1..2).class, (nil..nil).class, /x/n.encoding, /abc/.frozen?, (1..).frozen?] }
  t("a frozen literal") { r = /abc/; r.instance_variable_set(:@changed, true) }
RUBY

Dir.mktmpdir do |d|
  File.write(File.join(d, "main663.rb"), MAIN)
  File.write(File.join(d, "side663.rb"), SIDE)
  File.write(File.join(d, "lits663.rb"), LITS)
  runs = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, File.join(d, "main663.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  puts runs[0]
  puts "the same on the VM: #{runs[0] == runs[1]}"
  puts runs[1] unless runs[0] == runs[1]
end
