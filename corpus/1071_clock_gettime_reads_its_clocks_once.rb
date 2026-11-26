# Process.clock_gettime with a CLOCK_ number checks it against the CLOCK_
# constants, read once (it asked Process.constants on every call, and each
# call left that table behind). Module#constants answers the same each time.
p Process.clock_gettime(Process::CLOCK_MONOTONIC).class
p Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond).class
p Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID, :nanosecond).class
p Process.clock_getres(Process::CLOCK_MONOTONIC).class
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
3000.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
p Process.clock_gettime(Process::CLOCK_MONOTONIC) >= t0
[99, -5].each do |c|
  begin
    Process.clock_gettime(c)
    p [c, :ok]
  rescue => e
    p [c, e.class, e.message]
  end
end
begin
  Process.clock_gettime("x")
rescue TypeError => e
  p e.message
end
o = Object.new
def o.to_int = Process::CLOCK_MONOTONIC
p Process.clock_gettime(o).class
p Process.constants.grep(/\ACLOCK_/).sort == Process.constants.grep(/\ACLOCK_/).sort
p Process.constants.grep(/__clock/)
module M1071; A = 1; B = 2; end
p 1000.times.map { M1071.constants.sort }.uniq
