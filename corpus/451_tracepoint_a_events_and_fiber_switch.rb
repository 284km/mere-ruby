# :a_call is every call event (:call, :b_call, :c_call), :a_return every
# return event.
def with_block = yield
evs = []
TracePoint.new(:a_call) { |tp| evs << tp.event }.enable { [1].map! { 3 }; with_block { 4 } }
p evs
evs = []
TracePoint.new(:a_return) { |tp| evs << tp.event }.enable { [1].map! { 3 }; with_block { 4 } }
p evs

# :fiber_switch, on the side the thread arrives at: each resume, yield and
# transfer, and the end of a fiber.
evs = []
TracePoint.new(:fiber_switch) { |tp| evs << tp.event }.enable {
  f = Fiber.new { Fiber.yield; Fiber.yield; Fiber.yield }
  4.times { f.resume }
  begin
    f.resume
  rescue FiberError
  end
}
p evs.size, evs.uniq

# ...and an exception that ends a fiber is raised again in its resumer.
evs = []
f = nil
TracePoint.new(:raise, :fiber_switch) { |tp| evs << [tp.event, Fiber.current == f ? :f : :main] }.enable {
  f = Fiber.new { Fiber.yield; Fiber.yield }
  begin
    f.resume
    f.raise StopIteration
  rescue StopIteration
    evs << :rescued
  end
}
p evs

# A fiber that was resumed and transferred away is resumed still when it is
# transferred back to: its Fiber.yield goes to its resumer.
evs = []
TracePoint.new(:fiber_switch) { |tp| evs << tp.event }.enable {
  f1 = f2 = nil
  f1 = Fiber.new { f2.transfer; f2.transfer; Fiber.yield :ok }
  f2 = Fiber.new { f1.transfer; f1.transfer }
  p f1.resume
}
p evs.size

# Thread::Queue's methods are builtins: :c_call, with an alias reported by
# the name it aliases (callee_id is the name it was called by); #pop is
# written in Ruby (<internal:thread_sync>), a :call.
q = Thread::Queue.new
r = []
TracePoint.new(:c_call, :call) { |tp| r << [tp.event, tp.method_id, tp.callee_id] }.enable {
  q.push 1; q << 2; q.enq 3; q.pop; q.shift; q.size; q.empty?
}
r.each { p _1 }

# Thread#add_trace_func sees a queue's push as a c-call too.
def nop; end
events = []
base = __LINE__
q = Thread::Queue.new
t = Thread.new {
  Thread.current.add_trace_func proc { |ev, file, line, *|
    events << [ev, line - base] if file == __FILE__
  }
  q.push 1
  _x = 1
  nop
}
q.pop
t.join
events.each { p _1 }
