# Run with CRuby or mere-ruby. MERE_RUBY_GC_LOG=1 also reports mark-table sizes.
# The first call's temporary strings die before the second call collects,
# while the enclosing expression still has an allocation interval to scan.
def discard_strings(count)
  count.times { |i| i.to_s + 'temporary' }
  GC.start
  nil
end

def collect_repeatedly(count)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count.times { GC.start }
  warn "collections=#{count} seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
  :collected
end

p [discard_strings(Integer(ARGV.fetch(0, '100000'))),
   collect_repeatedly(Integer(ARGV.fetch(1, '20')))]
