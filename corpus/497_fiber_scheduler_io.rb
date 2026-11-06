require 'socket'
Warning[:experimental] = false

class WaitScheduler
  attr_reader :events
  def initialize
    @events = []
    @waiting = {}
  end
  def block(*) = false
  def unblock(*) = nil
  def kernel_sleep(*) = nil
  def fiber_interrupt(*) = nil
  def fiber(*args, **kw, &block)
    @events << [args, kw] unless args.empty? && kw.empty?
    fiber = Fiber.new(blocking: false) { block.call(*args, **kw) }
    fiber.resume
    fiber
  end
  def io_wait(io, events, timeout)
    @waiting[Fiber.current] = [io, events, timeout]
    Fiber.yield
  end
  def scheduler_close
    @events << [:closing, Fiber.scheduler.equal?(self), Fiber.current_scheduler.nil?]
    until @waiting.empty?
      waiting, @waiting = @waiting, {}
      waiting.each do |fiber, (io, events, timeout)|
        ready = IO.select(events & IO::READABLE != 0 ? [io] : [],
                          events & IO::WRITABLE != 0 ? [io] : [], [], timeout)
        fiber.resume(ready ? events : 0)
      end
    end
  end
end

begin
  Fiber.schedule {}
rescue => error
  p [error.class, error.message]
end
p Fiber.respond_to?(:schedule)
s = WaitScheduler.new
Fiber.set_scheduler(s)
p [Fiber.scheduler.equal?(s), Fiber.current_scheduler.nil?]
result = Fiber.schedule(7, label: :value) do |number, label:|
  p [number, label, Fiber.current_scheduler.equal?(s), Fiber.blocking?]
end
p [result.class, result.alive?]
Fiber.set_scheduler(nil)

p s.events

# A read suspends its fiber, allowing the peer's writer to run; closing
# the scheduler drains the pending read before Thread#join returns.
thread = Thread.new do
  scheduler = WaitScheduler.new
  Fiber.set_scheduler(scheduler)
  reader, writer = UNIXSocket.pair
  text = nil
  Fiber.schedule { text = reader.read(20); reader.close }
  Fiber.schedule { writer.write('hello'); writer.close }
  # The pending callback must retain this return value across GC.
  [scheduler, -> { text }, 'thread result']
end
scheduler, get_text, value = thread.value
p [get_text.call, value, scheduler.events]

# Clearing/replacing runs the old scheduler, and scheduler_close takes
# precedence over a legacy close hook.
class ClosingScheduler < WaitScheduler
  attr_accessor :fail_close
  def close = raise('wrong close hook')
  def scheduler_close
    super
    GC.start
    raise 'close failed' if fail_close
  end
end
s = ClosingScheduler.new
Fiber.set_scheduler(s)
replacement = WaitScheduler.new
Fiber.set_scheduler(replacement)
p [s.events, Fiber.scheduler.equal?(replacement)]
Fiber.set_scheduler(nil)
s = ClosingScheduler.new
s.fail_close = true
Fiber.set_scheduler(s)
begin
  Fiber.set_scheduler(nil)
rescue => error
  p [error.message, Fiber.scheduler.nil?]
end

# Without a block, the scheduler decides how to handle the call.
class NoBlockScheduler < WaitScheduler
  def fiber(*args, **kw, &block) = [args, kw, block.nil?]
end
Fiber.set_scheduler(NoBlockScheduler.new)
p Fiber.schedule(9, key: :test)
Fiber.set_scheduler(nil)

# Forwarding &block into Fiber.new must consume its identity. The next
# invocation must receive its own block, even after the first transfers.
class TransferFactory
  def run(&block)
    Fiber.new(blocking: false, &block).transfer
  end
end
factory = TransferFactory.new
factory.run { p :first }
factory.run { p :second }

# IO.select's optional hook gets the arguments unchanged, before the
# ordinary implementation validates them. Without the hook, use select
# itself, rather than translating a one-descriptor select into io_wait.
class SelectScheduler < WaitScheduler
  def io_select(*args) = [:selected, args]
end
Fiber.set_scheduler(SelectScheduler.new)
Fiber.schedule { p IO.select; p IO.select([], nil, nil, 0) }
Fiber.set_scheduler(nil)
Fiber.set_scheduler(WaitScheduler.new)
r, w = IO.pipe
Fiber.schedule { p IO.select([r], [], [], 0.001) }
r.close
w.close
Fiber.set_scheduler(nil)

# A blocking fiber can see the configured scheduler but must not use it.
s = WaitScheduler.new
Fiber.set_scheduler(s)
Fiber.new(blocking: true) { p [Fiber.scheduler.equal?(s), Fiber.current_scheduler] }.resume
class SubFiber < Fiber; end
SubFiber.schedule { p :subclass }
Fiber.set_scheduler(nil)

# A rejected replacement leaves the current scheduler untouched.
s = ClosingScheduler.new
Fiber.set_scheduler(s)
begin
  Fiber.set_scheduler(Object.new)
rescue ArgumentError
  p [Fiber.scheduler.equal?(s), s.events.empty?]
end
Fiber.set_scheduler(nil)
