# Scheduler setup can load IO::Buffer; its unrelated experimental notice
# is excluded from this conversion/ordering fixture on both interpreters.
Warning[:experimental] = false
# Native unsigned-int conversion happens after PID conversion and before
# scheduler dispatch or child lookup. A scheduler exposes the exact C int.
class FlagsScheduler1118
  attr_reader :calls
  def initialize = @calls = []
  def block(*) = false
  def unblock(*) = nil
  def kernel_sleep(*) = 0
  def io_wait(*) = 0
  def fiber_interrupt(*) = nil
  def process_wait(pid, flags)
    @calls << [pid, flags]
    nil
  end
end

class FlagInteger1118
  def initialize(value) = @value = value
  def to_int = @value
end
class PrivateFlagInteger1118 < FlagInteger1118
  private :to_int
end

scheduler = FlagsScheduler1118.new
Fiber.set_scheduler(scheduler)
begin
  Fiber.new(blocking: false) do
    # WNOHANG bypasses the scheduler on Ruby; use even flags for this hook.
    [nil, 0, 2, -2, -2147483648, 2147483646, 2147483648, 4294967294,
     0.9, -0.9, 2.9, -2.9, 4294967294.5, -2147483648.5,
     FlagInteger1118.new(2), PrivateFlagInteger1118.new(2)].each do |flags|
      p Process.wait(2147483647, flags)
    end
  end.resume
ensure
  Fiber.set_scheduler(nil)
end
p scheduler.calls

[4294967296, -2147483649, 2**63, -(2**63)-1, 2**64-1, 2**64,
 -(2**64), Float::INFINITY, -Float::INFINITY, Float::NAN,
 2.0**64, -2.0**64, false, true, '1', FlagInteger1118.new(nil),
 FlagInteger1118.new(1.5)].each_with_index do |flags, index|
  begin
    Process.wait(2147483647, flags)
  rescue TypeError, RangeError => error
    p [index, error.class, error.message]
  end
end

# Invalid flags must not reach the scheduler; PID conversion goes first.
order = []
pid = Object.new
pid.define_singleton_method(:to_int) { order << :pid; 2147483647 }
flags = Object.new
flags.define_singleton_method(:to_int) { order << :flags; 2**64 }
begin
  Process.wait(pid, flags)
rescue RangeError => error
  p [error.class, error.message, order]
end
[:waitpid, :wait2, :waitpid2].each do |method|
  begin
    Process.__send__(method, 2147483647, 2**64)
  rescue RangeError => error
    p [method, error.class, error.message]
  end
end
