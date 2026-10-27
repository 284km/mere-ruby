# fork is fork(2) (note 436): the child is another process with its own pid,
# a block's child ends after the block (at_exit included, status from exit
# or 1 for an unrescued exception), the parent waits for it like a spawned
# child, and IO.popen("-") connects the child's stdin and stdout to the pipe.
$stdout.sync = true
print "once "
pid = fork
if pid.nil?
  puts "child #{Process.pid != Process.ppid}"
  exit! 3
end
_, st = Process.wait2(pid)
puts "parent: child exited #{st.exitstatus}"

pid = fork { puts "in block"; exit 5 }
Process.wait(pid)
p $?.exitstatus

pid = fork { $stderr.reopen(File::NULL, "w"); raise "boom" }
Process.wait(pid)
p $?.exitstatus

$main = Process.pid
at_exit { puts "at_exit in #{Process.pid == $main ? "parent" : "child"}" }
pid = fork { puts "block2" }
Process.wait(pid)

IO.popen("-") do |io|
  if io
    puts "parent read: #{io.read.inspect}"
  else
    puts "from child"
  end
end

io = IO.popen("-", "r+")
if io
  io.puts "ping"
  io.close_write
  puts "parent got #{io.read.inspect}"
  io.close
  p $?.success?
else
  puts "pong:" + $stdin.gets.to_s
  exit!
end

p Process.respond_to?(:fork), respond_to?(:fork, true), Process.respond_to?(:daemon)
p Object.new.respond_to?(:sleep, true), Object.new.respond_to?(:sleep)

# Process._fork is the hook both forms go through
module ForkHook
  def _fork
    pid = super
    puts "hooked in parent" if pid > 0
    pid
  end
end
Process.singleton_class.prepend(ForkHook)
pid = fork { }
Process.wait(pid)

r, w = IO.pipe
pid = fork do
  r.close
  w.puts "child's pid differs: #{Process.pid != $main}"
end
w.close
puts r.read
Process.wait(pid)
begin
  Process.wait
rescue Errno::ECHILD
  puts "no children left"
end

# a break out of a block whose method has an ensure that itself returns from
# a loop (IO#close waits for its child that way): the break still reaches
# the method it was written in
def helper_loop_return
  loop do
    return 1
  end
end
def with_ensure
  yield
ensure
  helper_loop_return
end
def breaks_out = with_ensure { break :broke }
p breaks_out
def first_line = IO.popen(["echo", "hi"]) { |f| break f.read }
p first_line
def caught = catch(:t) { with_ensure { throw :t, :thrown } }
p caught
