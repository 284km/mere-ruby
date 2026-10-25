# A buffer a waiting read holds is locked, puts of an array that holds
# itself, $> and $stdout as one variable, and dup at the descriptor limit

r, w = IO.pipe
buf = +""
t = Thread.new { r.readpartial(10, buf) }
Thread.pass until t.stop?
begin
  buf.replace("x")
  p :no_raise
rescue => e
  p [e.class, e.message]
end
w.write "abc"
p t.value, buf
p buf.frozen?
buf << "d"
p buf

r2, w2 = IO.pipe
b2 = +""
t2 = Thread.new { r2.sysread(4, b2) }
Thread.pass until t2.stop?
p((b2.clear rescue $!.class))
w2.write "wxyz"
p t2.value
[r, w, r2, w2].each(&:close)

a = [1]
a << a
s = Class.new { define_method(:to_ary) { [2, self] } }.new
$stdout.puts a
$stdout.puts [s].flatten(0).size

old = $stdout
$> = $stderr
same = $stdout.equal?($stderr)
$stdout = old
p same
p $>.equal?(old)
begin
  $> = Object.new
rescue TypeError => e
  p e.message
end

lim = Process.getrlimit(:NOFILE)
Process.setrlimit(:NOFILE, 64, lim[1])
held = []
begin
  loop { held << IO.pipe }
rescue SystemCallError => e
  p e.class
end
begin
  loop { held << [held[-1][0].dup, held[-1][1].dup] }
rescue SystemCallError => e
  p e.class
end
held.flatten.each(&:close)
Process.setrlimit(:NOFILE, *lim)
p IO.pipe.map(&:class)
