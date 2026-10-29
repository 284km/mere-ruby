# TracePoint after sweep464: an event's binding (the locals the scope will
# assign are there already, nil), set_trace_func handing it over, hooks on a
# target after the global ones and newest first, target: a Proc and
# target_line:, the :line ruby's own enable / disable make, a thread's events
# on no line, :rescue on the clause's first line, loop's :call / :return, and
# `X.new` making no :c_call of Class#new.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# the binding of :line / :call / :return / :raise
class Traced
  def run(n)
    k = n * 2
    raise ArgumentError, "x" if k > 100
    k + 1
  end
end
seen = []
tp = TracePoint.new(:line, :call, :return, :raise) do |t|
  next unless t.path == __FILE__ && t.defined_class == Traced
  b = t.binding
  seen << [t.event, t.lineno, b && b.local_variable_defined?(:k), b && b.eval("k")]
end
tp.enable { Traced.new.run(3); (Traced.new.run(60) rescue nil) }
seen.each { |s| puts "binding #{s.inspect}" }

# a class body's :line and :end see its locals
cls_seen = []
TracePoint.new(:line, :end) do |t|
  cls_seen << [t.event, t.binding.eval("z")] if t.path == __FILE__ && t.self.is_a?(Class) && t.self.name == "TracedBody"
end.enable do
  class TracedBody
    z = :zed
    z
  end
end
show("class body") { cls_seen }

# set_trace_func gets the binding too (nil for a C method's event)
stf = []
lv = :outer
set_trace_func(proc { |ev, file, line, id, bnd, klass|
  stf << [ev, bnd ? bnd.eval("lv") : nil] if file == __FILE__ && (ev == "line" || ev == "c-call")
})
lv = :inner
lv.to_s
set_trace_func(nil)
show("set_trace_func") { stf.first(4) }

# hooks: the global ones first, then those on the target, newest first
code1 = proc {
  _a = 1
}
ev = []
t1 = TracePoint.new(:line) { |t| ev << [:t1, t.lineno - __LINE__] if t.path == __FILE__ }
t2 = TracePoint.new(:line) { |t| ev << [:t2, t.lineno - __LINE__] }
t1.enable do
  t2.enable(target: code1) { code1.call }
end
show("global then target") { ev }
ev = []
t3 = TracePoint.new(:line) { |t| ev << :t3 }
t4 = TracePoint.new(:line) { |t| ev << :t4 }
t3.enable(target: code1) { t4.enable(target: code1) { code1.call } }
show("two on a target") { ev }

# the errors of enable / disable with a target
show("nest-enable") { tp5 = TracePoint.new(:line) {}; tp5.enable(target: code1) { tp5.enable(target: code1) {} } }
show("nest global") { tp6 = TracePoint.new(:line) {}; tp6.enable(target: code1) { tp6.enable {} } }
show("disable in block") { tp7 = TracePoint.new(:line) {}; tp7.enable(target: code1) { tp7.disable {} } }
show("only target_line") { TracePoint.new(:line) {}.enable(target_line: 3) {} }
show("target_line, no line") { TracePoint.new(:call) {}.enable(target: code1, target_line: 3) {} }

# target_line: the one line of the target
base = __LINE__
code2 = proc {
  ev << 1
  ev << 2
}
ev = []
TracePoint.new(:line) { |t| ev << :hit }.enable(target: code2, target_line: base + 3) { code2.call }
show("target_line") { ev }

# the :line ruby's own Ruby code in enable / disable makes, which the other
# tracepoints see
own = []
outer = TracePoint.new(:line) { |t| own << [t.path, t.lineno, t.method_id] if t.path.start_with?("<internal:trace") }
inner = TracePoint.new(:call) {}
outer.enable
inner.enable
inner.disable
outer.disable
show("internal lines") { own }

# a thread's begin and end are on no line
th_ev = []
TracePoint.new(:thread_begin, :thread_end) { |t| th_ev << [t.event, t.lineno, t.path] }.enable(target_thread: nil) do
  Thread.new {}.join
end
show("thread events") { th_ev.uniq }

# :rescue is on the first line of the clause that handles it
def rescues
  begin
    raise "a"
  rescue TypeError
    :no
  rescue
    :yes
  end
end
def rescues_empty
  begin
    raise "b"
  rescue
  end
end
rl = []
base = __LINE__
TracePoint.new(:rescue) { |t| rl << t.lineno }.enable { rescues; rescues_empty }
show("rescue lines") { rl.map { |l| l - base } }

# loop is ruby's Ruby: :call and :return, also when left by return / break
class Looper
  def initialize
    loop { return }
  end
  def brk = loop { break 4 }
end
le = []
TracePoint.new(:call, :return, :c_call) { |t| le << [t.event, t.method_id] if [:loop, :initialize, :brk, :new].include?(t.method_id) }.enable do
  Looper.new.brk
end
show("loop events") { le }

# Exception#initialize returns the exception
rv = []
TracePoint.new(:c_return) { |t| rv << t.return_value.class if t.method_id == :initialize }.enable { raise "z" rescue nil }
show("initialize return_value") { rv }

# `X.new` without a block reaches Class#new as opt_new: no :c_call of it.
# With a block, through send, or for String's own `new`, there is one.
S1 = Struct.new(:a)
nw = []
TracePoint.new(:c_call) { |t| nw << [t.defined_class.inspect, t.lineno - __LINE__] if t.method_id == :new }.enable do
  Object.new
  S1.new(1)
  Looper.allocate
  String.new("x")
  Object.new(&nil)
end
show("c_call new") { nw }
