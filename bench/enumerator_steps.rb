# Isolate corpus/214's repeated, suspended generators inside one statement.
# Run the identical workload with the O2 candidate and the reference Ruby.
count = Integer(ARGV.fetch(0, '9000'))
raise ArgumentError, 'count must be positive' unless count > 0
kept = Enumerator.new { |y| y << :kept1; y << :kept2 }
p kept.next
p count.times.count { |k| Enumerator.new { |y| y << k }.next == k }
p kept.next
