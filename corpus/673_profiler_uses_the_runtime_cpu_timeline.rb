def process_cpu
  Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
end

def burn_cpu(seconds)
  start = process_cpu
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
  value = 0
  while process_cpu - start < seconds
    25_000.times { |i| value ^= i }
    raise 'process CPU clock did not advance' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end
  value
end

GC.disable
burn_cpu(0.2)
GC::Profiler.enable
GC.start
first = GC::Profiler.raw_data.last
raise 'enable reset the startup timeline' unless first[:GC_INVOKE_TIME] >= 0.15
raise 'collection duration missing' unless first[:GC_TIME] > 0

GC::Profiler.clear
burn_cpu(0.1)
GC.start
second = GC::Profiler.raw_data.last
raise 'clear reset the startup timeline' unless second[:GC_INVOKE_TIME] > first[:GC_INVOKE_TIME]

GC::Profiler.disable
burn_cpu(0.1)
GC::Profiler.enable
GC.start
third = GC::Profiler.raw_data.last
raise 're-enable reset the startup timeline' unless third[:GC_INVOKE_TIME] > second[:GC_INVOKE_TIME]

GC::Profiler.clear
sleep 0.25
GC.start
after_sleep = GC::Profiler.raw_data.last
raise 'sleep was charged as process CPU' unless after_sleep[:GC_INVOKE_TIME] - third[:GC_INVOKE_TIME] < 0.2
GC::Profiler.disable
GC.enable
puts 'profiler CPU timestamps retain their runtime startup epoch'
