# load of a FIFO a thread of this process writes, as the writer fills it
require "tmpdir"
require "rbconfig"
require "socket"
Dir.mktmpdir do |d|
  path = File.join(d, "f.rb")
  File.mkfifo(path)
  th = Thread.current
  $ok = false
  Thread.start do
    sleep(0.001) until th.stop?
    open(path, File::WRONLY | File::NONBLOCK) { |w| w.print "$ok = true\n__END__\n" }
  end
  load(path)
  p $ok

  # ...and an exception raised into the loading thread while it waits
  path2 = File.join(d, "g.rb")
  File.mkfifo(path2)
  Thread.start { sleep(0.001) until th.stop?; th.raise(IOError) }
  p((load(path2) rescue $!.class))
end

ruby = RbConfig.ruby

# exec keeps the pid: the child execs, and what it then prints is its own pid
IO.popen([ruby, "-e", "STDOUT.sync = true; puts $$; exec(#{ruby.dump}, '-e', 'puts $$')"]) do |io|
  a, b = io.read.split
  p a == b
end

# Process.daemon forks once: the daemon leads its own session
r, w = IO.pipe
pid = fork do
  r.close
  Process.daemon(true, true)
  w.puts(Process.getsid == Process.pid)
  w.close
end
w.close
Process.wait(pid)
puts r.read

# the [BUG] report's backtrace: the frames' own names, an END block's frame
# as "block in <main>"
src = "def bar = [1].map { Process.kill :SEGV, $$ }\nEND { bar }"
err = IO.popen([ruby, "-e", src], err: [:child, :out], &:read)
puts err[/^-- Ruby level backtrace information -+\n(.*?)\n\n/m, 1]

# a glob with no descriptor left is EMFILE naming the directory it opens
soft, hard = Process.getrlimit(:NOFILE)
Process.setrlimit(:NOFILE, 64, hard)
files = []
begin
  loop { files << File.open(__FILE__) }
rescue Errno::EMFILE => e
  p e.class
end
p((Dir.glob(File.join(__dir__, "*")) rescue $!.message.sub(__dir__, "DIR")))
p Dir.glob(File.join(__dir__, "no_such_dir", "*"))
files.each(&:close)
Process.setrlimit(:NOFILE, soft, hard)
p Dir.glob(File.join(__dir__, "465_*")).size

# IO.select's third array: an out-of-band byte
TCPServer.open("127.0.0.1", 0) do |svr|
  con = TCPSocket.new("127.0.0.1", svr.addr[1])
  acc = svr.accept
  p IO.select(nil, nil, [acc], 0)
  p con.send("hello", Socket::MSG_OOB)
  set = IO.select(nil, nil, [acc], 5)
  p set && set[2] == [acc]
  acc.close
  con.close
end
p Process.setproctitle("corpus 465")
