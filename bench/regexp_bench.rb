# Regexp workloads, one per run: `ruby bench/regexp_bench.rb NAME`. Each
# prints its CPU seconds and a count, so the two interpreters are compared on
# the answer as well as the time (bench/regexp.sh runs them all).
words = %w[alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu]
text = Array.new(4000) { |i| "#{words[i % 12]} #{i} foo@example.com, x=#{i * 7}; key_#{i}: value-#{i}\n" }.join
csv = Array.new(3000) { |i| "#{i},name#{i},#{i * 3.5},\"quoted, #{i}\",end" }.join("\n")
log = Array.new(3000) { |i| "2026-11-05 12:#{format('%02d', i % 60)}:00 [#{%w[INFO WARN ERROR][i % 3]}] req=#{i} took #{i % 97}ms path=/api/v1/items/#{i}" }.join("\n")
which = ARGV[0]
t0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
r = case which
when "scan_words"   then 5.times.sum { text.scan(/\w+/).size }
when "scan_email"   then 20.times.sum { text.scan(/[a-z]+@[a-z]+\.com/).size }
when "gsub_digits"  then 5.times.sum { text.gsub(/\d+/, "#").size }
when "split_csv"    then 10.times.sum { csv.split(/,/).size }
when "match_lines"  then 5.times.sum { log.each_line.count { |l| l =~ /\[ERROR\]/ } }
when "capture_log"  then 5.times.sum { log.scan(/^(\S+) (\S+) \[(\w+)\] req=(\d+) took (\d+)ms/).size }
when "literal_find" then 50.times.sum { text.index(/key_3999/) || 0 }
when "anchored"     then 20000.times.count { |i| "value-#{i}" =~ /\Avalue-\d+\z/ }
when "alternation"  then 10.times.sum { text.scan(/alpha|gamma|kappa|mu/).size }
when "dotstar"      then 5.times.sum { log.scan(/path=(.*)$/).size }
when "classes"      then 5.times.sum { csv.scan(/"[^"]*"/).size }
when "ci"           then 10.times.sum { text.scan(/ALPHA|BETA/i).size }
when "nomatch"      then 30.times.count { text =~ /zzz\d+qqq/ }
end
t1 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
printf("%-13s %8.3f  %s\n", which, t1 - t0, r)
