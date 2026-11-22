gate = Thread::Queue.new
worker = Thread.new do
  gate.pop
  value = 1
end
kept = []
threads = {}
point = TracePoint.new(:line) do |event|
  next unless event.path == __FILE__
  threads[Thread.current] = true
  before = [event.event, event.path, event.lineno, event.method_id,
            event.callee_id, event.defined_class, event.self, event.inspect]
  Thread.pass
  after = [event.event, event.path, event.lineno, event.method_id,
           event.callee_id, event.defined_class, event.self, event.inspect]
  kept << (before == after)
end
point.enable(target_thread: nil) do
  gate.push(true)
  value = 2
  worker.join
end
p [kept.any?, kept.all?, threads.size == 2]

ready = Thread::Queue.new
release = Thread::Queue.new
start = Thread::Queue.new
worker = Thread.new do
  start.pop
  value = 3
end
armed = true
outside = false
stable = false
point = TracePoint.new(:line) do |event|
  next unless armed && event.path == __FILE__
  armed = false
  before = [event.event, event.lineno, event.method_id]
  ready.push(true)
  release.pop
  stable = before == [event.event, event.lineno, event.method_id]
end
point.enable(target_thread: worker) do
  start.push(true)
  ready.pop
  begin
    point.method_id
  rescue RuntimeError => error
    outside = error.message == 'access from outside'
  ensure
    release.push(true)
  end
  worker.join
end
p [outside, stable]

armed = true
restored = false
point = TracePoint.new(:line) do |event|
  next unless armed && event.path == __FILE__
  armed = false
  before = [event.event, event.path, event.lineno, event.method_id, event.inspect]
  TracePoint.allow_reentry do
    nested = 1
  end
  restored = before == [event.event, event.path, event.lineno, event.method_id, event.inspect]
end
point.enable do
  outer = 1
end
p restored

def tracepoint_fiber_target
  :ok
end
stable = false
outside = false
point = TracePoint.new(:call) do |event|
  next unless event.method_id == :tracepoint_fiber_target
  before = [event.event, event.method_id, event.lineno]
  Fiber.yield
  stable = before == [event.event, event.method_id, event.lineno]
end
fiber = Fiber.new { tracepoint_fiber_target }
point.enable do
  fiber.resume
  begin
    point.method_id
  rescue RuntimeError => error
    outside = error.message == 'access from outside'
  end
  fiber.resume
end
p [outside, stable]

point = TracePoint.new(:line) { raise 'callback failed' }
begin
  point.enable do
    value = 4
  end
rescue RuntimeError => error
  p error.message == 'callback failed'
end
begin
  point.event
rescue RuntimeError => error
  p error.message == 'access from outside'
end
