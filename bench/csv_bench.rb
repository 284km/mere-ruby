# CSV under mere-ruby vs ruby, on the same bytes. Driven by bench/csv.sh,
# which finds the gem and runs this same file under both.
#
# Every timing prints the row / field / byte count it produced: two sides that
# did different amounts of work are not a comparison, and CSV.parse silently
# returning every other row is exactly the shape of bug this hides.
require "csv"

ROWS = (ENV["ROWS"] || "400").to_i
REPS = (ENV["REPS"] || "3").to_i

plain = +"c1,c2,c3,c4,c5,c6,c7,c8\n"
ROWS.times do |i|
  plain << "#{i},plain#{i},abc,def,#{i * 7},ghi,jkl,mno\n"
end

quoted = +"c1,c2,c3,c4,c5,c6,c7,c8\n"
ROWS.times do |i|
  quoted << %Q{#{i},"has,comma #{i}",abc,"has ""quotes"" #{i}",#{i * 7},ghi,"x",mno\n}
end

def bench(label, reps)
  best = nil
  info = nil
  reps.times do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    info = yield
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    d = t1 - t0
    best = d if best.nil? or d < best
  end
  printf("%-26s %8.3f s   %s\n", label, best, info)
end

bench("parse (plain)", REPS)         { "rows=#{CSV.parse(plain).size}" }
bench("parse (quoted)", REPS)        { "rows=#{CSV.parse(quoted).size}" }
bench("parse headers (plain)", REPS) { "rows=#{CSV.parse(plain, headers: true).size}" }
bench("parse_line x#{ROWS}", REPS) do
  line = plain.lines[1]
  n = 0
  ROWS.times { n += CSV.parse_line(line).size }
  "fields=#{n}"
end
bench("generate_line x#{ROWS}", REPS) do
  row = CSV.parse_line(plain.lines[1])
  n = 0
  ROWS.times { n += CSV.generate_line(row).bytesize }
  "bytes=#{n}"
end
