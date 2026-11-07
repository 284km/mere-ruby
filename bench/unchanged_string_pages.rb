# Keep strings across repeated collections, then change some old strings.
count = Integer(ARGV.fetch(0, '20000'))
rounds = Integer(ARGV.fetch(1, '20'))
strings = Array.new(count) { |i| ('x' * 256) + i.to_s }
GC.start
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
rounds.times { GC.start }
warn "collections=#{rounds} seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
p strings.each_with_index.all? { |s, i| s == ('x' * 256) + i.to_s }
strings.each_with_index { |s, i| s.replace("changed#{i}") if i % 499 == 0 }
GC.start
p strings.each_with_index.all? { |s, i| s == (i % 499 == 0 ? "changed#{i}" : ('x' * 256) + i.to_s) }
