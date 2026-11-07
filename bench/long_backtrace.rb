# A long explicit trace isolates formatting from the interpreter's recursion
# limit. Run the same file with the baseline and candidate binaries.
count = Integer(ARGV.fetch(0, '15000'))
error = RuntimeError.new('long trace')
error.set_backtrace(Array.new(count) { |i| "bench.rb:#{i + 1}:in 'frame'" })
message = error.full_message(highlight: false, order: :top)
p [message.bytesize, message.lines.length, message.lines.first, message.lines.last]
