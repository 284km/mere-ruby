# Process.clock_gettime read the wall clock for every clock id but the
# process CPU one. CLOCK_MONOTONIC then went back whenever the time was set,
# and minitest timed a test at -3.35 s (Rails' migration/compatibility_test).
# A monotonic clock counts from boot, so it is far below the epoch seconds the
# wall clock gives; the CPU clocks count this process's own time.

real = Process.clock_gettime(Process::CLOCK_REALTIME)
p real > 1_700_000_000

# (named, not numbered: the numbers are the platform's own, and the uptime
#  and the approximate clocks are darwin's -- asked where they exist)
monotonic = %i[CLOCK_MONOTONIC CLOCK_MONOTONIC_RAW CLOCK_MONOTONIC_RAW_APPROX
               CLOCK_UPTIME_RAW CLOCK_UPTIME_RAW_APPROX]
monotonic.each do |name|
  next unless Process.const_defined?(name)
  c = Process.const_get(name)
  a = Process.clock_gettime(c)
  b = Process.clock_gettime(c)
  # not the wall clock (a machine up for 30 years would fail this), and
  # never going back
  ok = a.is_a?(Float) && a < real - 1_000_000_000 && b >= a
  puts "#{name}: #{ok}" if %i[CLOCK_MONOTONIC CLOCK_MONOTONIC_RAW].include?(name)
  puts "not monotonic: #{name}" unless ok
end
if RUBY_PLATFORM.include?("darwin")
  a = Process.clock_gettime(:MACH_ABSOLUTE_TIME_BASED_CLOCK_MONOTONIC)
  puts "mach absolute time" unless a < real - 1_000_000_000
end

# the CPU clocks: this process has used well under a day of CPU
{ "process" => Process::CLOCK_PROCESS_CPUTIME_ID, "thread" => Process::CLOCK_THREAD_CPUTIME_ID,
  "getrusage" => :GETRUSAGE_BASED_CLOCK_PROCESS_CPUTIME_ID }.each do |name, c|
  t = Process.clock_gettime(c)
  p [name, t.class, t >= 0 && t < 86_400]
end

# the units read the same clock
m = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
p [m.class, m < (real - 1_000_000_000) * 1_000_000_000]
p Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond).class
p Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond).class

# time(2) gives whole seconds, gettimeofday(2) the wall clock too
t = Process.clock_gettime(:TIME_BASED_CLOCK_REALTIME)
p [t.class, t == t.floor, (t - real).abs < 5]
g = Process.clock_gettime(:GETTIMEOFDAY_BASED_CLOCK_REALTIME)
p [g.class, (g - real).abs < 5]

# elapsed time measured the way minitest does is never negative
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
x = 0
10_000.times { |i| x += i }
p Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 >= 0

begin
  Process.clock_gettime(12345)
rescue => e
  p e.class
end
