# With $stdout replaced, Kernel#puts/print/putc write THROUGH it -- puts hands
# over the line and its newline as two strings, as rb_io_writev does -- while
# STDOUT.puts/print/write/printf/putc still write to STDOUT itself. Kernel#putc
# writes one character of a String or the low byte of an Integer.
$log = []
o = Object.new
def o.write(*a) $log << a; a.sum(&:size) end
$stdout = o
STDOUT.print "p1\n"; STDOUT.puts "p2"; STDOUT.write "p3\n"; STDOUT << "p4\n"; STDOUT.printf("%s\n", "p5"); STDOUT.putc "Z"
putc "AB"; putc 66
print "k1"; puts "k2"
$stdout = STDOUT
p $log
o2 = Object.new
def o2.write(s) $log2 << s; s.size end
$log2 = []
$stdout = o2
puts "one"; puts "two\n"; puts; puts ["a", ["b"]]
$stdout = STDOUT
p $log2
p putc(65), putc("xyz"), STDOUT.putc(10)
begin
  putc nil
rescue TypeError => e
  p e.class
end
