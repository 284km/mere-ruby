# The C hooks a definition runs -- method_added, const_added, inherited --
# make c_call / c_return events even when nothing overrides them; and the
# per-thread trace functions and TracePoint.stat exist (note 448).

ev = []
set_trace_func(proc { |e, f, l, m, b, k|
  ev << [e, m, k] if e.start_with?("c-") && [:method_added, :const_added, :inherited].include?(m)
})
class Foo422; def x; end; end
class Bar422 < Foo422; end
def top422; end
module Mod422; end
set_trace_func(nil)
ev.each { |x| p x }

ids = []
tp = TracePoint.new(:c_call) { |t| ids << t.method_id if [:method_added, :const_added, :inherited].include?(t.method_id) }
tp.enable { eval("class Baz422; def y; end; end") }
p ids

p TracePoint.stat.class
p Thread.current.respond_to?(:add_trace_func), Thread.current.respond_to?(:set_trace_func)

a = Object.new.extend(Enumerable)
def a.each; yield; end
p Thread.start { Thread.current.add_trace_func(proc {}); a.any? { true } }.value

# a missing constant and a missing method run the C hooks too
ev2 = []
TracePoint.new(:c_call, :c_return) { |tp| ev2 << [tp.event, tp.method_id, tp.defined_class] if [:const_missing, :method_missing].include?(tp.method_id) }.enable { MISSING_422 rescue nil; missing_422 rescue nil }
p ev2

# and a thread's begin and end, for a TracePoint on every thread
tev = []
tpt = TracePoint.new(:thread_begin, :thread_end) { |t| tev << [t.event, t.self.class] }
tpt.enable(target_thread: nil) { Thread.new {}.join }
p tev
tev2 = []
tpt2 = TracePoint.new(:thread_begin) { |t| tev2 << t.event }
tpt2.enable { Thread.new {}.join }
p tev2
