# A Fiber scheduler answers for a non-blocking fiber: its waits on a Mutex,
# a Queue, a ConditionVariable and a Thread#join go through #block and
# #unblock; sleep is #kernel_sleep (and answers the seconds slept); a name is
# resolved by #address_resolve; I/O goes through #io_read / #io_write; a
# child is waited for by #process_wait. A small scheduler, as test/fiber's.
require "socket"

class TinyScheduler
  def initialize
    @ready = []
    @waiting = {}   # fiber => deadline or nil
    @log = []
  end
  attr_reader :log

  def fiber(&b)
    f = Fiber.new(blocking: false, &b)
    f.resume
    f
  end

  def block(blocker, timeout = nil)
    @log << [:block, blocker.class]
    @waiting[Fiber.current] = timeout && (now + timeout)
    Fiber.yield
  ensure
    @waiting.delete(Fiber.current)
  end

  def unblock(blocker, fiber)
    @log << [:unblock, blocker.class]
    @ready << fiber
  end

  def kernel_sleep(duration = nil)
    @log << [:kernel_sleep, duration]
    block(:sleep, duration)
  end

  def io_wait(io, events, timeout) = events
  def address_resolve(hostname) = ["10.0.0.7", "fe80::7"]

  def process_wait(pid, flags)
    @log << [:process_wait]
    Fiber.blocking { Process::Status.wait(pid, flags) }
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def close = run
  def scheduler_close = run

  def run
    until @ready.empty? && @waiting.empty?
      while (f = @ready.shift)
        f.resume if f.alive?
      end
      due = @waiting.select { |_, d| d && d <= now }.keys
      due.each { |f| @waiting.delete(f); f.resume if f.alive? }
      if @ready.empty? && !@waiting.empty? && @waiting.values.all?(&:nil?)
        # A joined thread can still be running outside this ready queue.
        # Give it a turn and wait for its unblock instead of dropping its fiber.
        Thread.pass
      end
    end
  end
end

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

result = {}
Thread.new do
  s = TinyScheduler.new
  Fiber.set_scheduler(s)

  m = Thread::Mutex.new
  order = []
  Fiber.schedule { m.synchronize { order << :a1; sleep 0.01; order << :a2 } }
  Fiber.schedule { m.synchronize { order << :b } }
  q = Thread::Queue.new
  Fiber.schedule { order << [:popped, q.pop] }
  Fiber.schedule { q << :item }
  cv = Thread::ConditionVariable.new
  m2 = Thread::Mutex.new
  Fiber.schedule { m2.synchronize { cv.wait(m2); order << :signalled } }
  Fiber.schedule { m2.synchronize { cv.signal } }
  Fiber.schedule do
    started = s.now
    seconds = sleep(0.01)
    # CRuby subtracts whole wall-clock seconds, so a 10 ms sleep may return
    # either 0 or 1. Compare the contract and elapsed duration, not that value.
    order << [:slept, seconds.is_a?(Integer) && seconds >= 0, s.now - started >= 0.01]
  end
  Fiber.schedule do
    t = Thread.new { :joined }
    order << [:value, t.value]
  end
  Fiber.schedule do
    ai = Addrinfo.getaddrinfo("example.invalid", 80, nil, :STREAM)
    order << [:resolved, ai.map(&:ip_address)]
  end
  Fiber.schedule do
    pid = spawn("true")
    order << [:waited, Process.wait(pid) == pid, $?.success?]
  end
  s.run
  result[:order] = order
  result[:hooks] = s.log.map(&:first).uniq.sort
end.join

# (two fibers wake from 10 ms sleeps, and which runs first is the clock's:
#  the mutex's exclusion is the fact, the rest is printed sorted)
show("mutex excludes") { o = result[:order]; o.index(:a1) < o.index(:a2) && o.index(:a2) < o.index(:b) }
show("order") { result[:order].sort_by(&:inspect) }
show("hooks") { result[:hooks] }

# a mutex held by another fiber of the thread is a deadlock to a fiber with
# no scheduler, as before
show("deadlock") do
  m = Thread::Mutex.new
  m.synchronize { Fiber.new { m.lock }.resume }
end

show("backtrace") { Fiber.current.backtrace(0, 1).first[/'(.*)'/, 1] }
show("finished fiber backtrace") { f = Fiber.new {}; f.resume; f.backtrace }
