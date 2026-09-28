# Threads are scheduled: a new thread waits at the end of the run queue while
# its creator runs on, and a thread that waits -- join, sleep, stop, a queue,
# a mutex, a condition variable, a monitor -- lets the others run until it is
# woken. Everything below is FIFO, as ruby's is, so the order is fixed.
Thread.report_on_exception = false
out = []
t = Thread.new { out << :a; 42 }
out << :main
p t.value
p out
ts = 3.times.map { |i| Thread.new(i) { |j| out << j } }
ts.each(&:join)
p out
p t.status, t.alive?
x = Thread.new { Thread.current[:k] = 1; sleep 0.05; :slept }
p x.status
p x.value
t = Thread.new { sleep }
Thread.pass until t.status == "sleep"
p t.status, t.stop?
t.wakeup; t.join
p t.status
k = Thread.new { sleep 10 }
Thread.pass
k.kill; k.join
p k.status, k.value
r = Thread.new { begin; sleep; rescue => ex; ex.message; end }
Thread.pass
r.raise("hi"); p r.value
p Thread.new { Thread.stop; :woke }.tap { |w| Thread.pass; w.run }.value
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); sleep 0.1; p (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) >= 0.1
a = Thread.new { 3.times { |i| print "a#{i} "; Thread.pass } }
b = Thread.new { 3.times { |i| print "b#{i} "; Thread.pass } }
a.join; b.join; puts
q = Queue.new
c = Thread.new { 3.times.map { q.pop } }
p q.num_waiting
3.times { |i| q << i }
p c.value
sq = SizedQueue.new(1)
prod = Thread.new { 3.times { |i| sq.push(i) }; :done }
r = []; 3.times { r << sq.pop }
p r, prod.value
m = Mutex.new; log = []
ts = 3.times.map { |i| Thread.new { m.synchronize { log << i; Thread.pass; log << i } } }
ts.each(&:join); p log
cv = ConditionVariable.new; ready = false
w = Thread.new { m.synchronize { cv.wait(m) until ready; :ok } }
Thread.pass
m.synchronize { ready = true; cv.signal }
p w.value
p q.pop(timeout: 0.05)
q.close; p q.pop
begin
  Queue.new.pop
rescue Exception => e
  p e.class, e.message.lines.first.chomp  # (ruby lists the threads after this line)
end
require "monitor"
mon = Monitor.new; c = mon.new_cond; items = []
cons = Thread.new { mon.synchronize { c.wait_while { items.empty? }; items.shift } }
Thread.pass
mon.synchronize { items << :x; c.signal }
p cons.value
p mon.mon_locked?, mon.try_enter, mon.mon_owned?
mon.exit
t = Thread.new { mon.synchronize { :inner } }
mon.enter; mon.enter; p mon.mon_owned?; mon.exit; mon.exit
p t.value
class Obj; include MonitorMixin; def initialize; super; @v = 0; end; def inc; synchronize { @v += 1 }; end; attr_reader :v; end
o = Obj.new; 5.times.map { Thread.new { o.inc } }.each(&:join); p o.v
begin; Monitor.new.exit; rescue ThreadError => e; p e.message; end
