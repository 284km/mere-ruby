# A connection another process accepts first: a nonblocking accept that
# readiness sent to accept(2) gets EAGAIN, which is IO::EAGAINWaitReadable
# (and :wait_readable with exception: false) -- the forked workers of one
# server all accept on the same listener. It was SocketError "accept failed",
# which puma's accept loop logged as a "Listen loop" error.
require "socket"
require "tmpdir"
l = TCPServer.new("127.0.0.1", 0)
port = l.addr[1]
c = TCPSocket.new("127.0.0.1", port)
IO.select([l])
pid = fork { s = l.accept; s.close; exit!(0) }   # the other process takes it
Process.wait(pid)
begin
  l.accept_nonblock
rescue IO::WaitReadable => e
  p [e.class, e.message]
end
p l.accept_nonblock(exception: false)
c.close

# ...and a blocking accept waits for the next connection
c2 = TCPSocket.new("127.0.0.1", port)
IO.select([l])
pid = fork { s = l.accept; s.close; exit!(0) }
Process.wait(pid)
t = Thread.new { s = l.accept; s.close; :accepted }
sleep 0.2
c3 = TCPSocket.new("127.0.0.1", port)
p t.value
[c2, c3].each(&:close)

# UNIXServer the same
path = File.join(Dir.tmpdir, "corpus-accept-#{Process.pid}.sock")
u = UNIXServer.new(path)
uc = UNIXSocket.new(path)
IO.select([u])
pid = fork { s = u.accept; s.close; exit!(0) }
Process.wait(pid)
p u.accept_nonblock(exception: false)
uc.close
u.close
File.unlink(path)

# Three forked processes accepting on one listener, as a cluster's workers
# do: readiness says a connection waits, another process takes it, and
# accept_nonblock must answer WaitReadable rather than raise or wait. Each
# of the 120 connections is taken exactly once, and nothing else is raised.
l2 = TCPServer.new("127.0.0.1", 0)
port2 = l2.addr[1]
r, w = IO.pipe
kids = 3.times.map do
  fork do
    r.close
    taken = 0
    others = []
    stop = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < stop
      next unless IO.select([l2], nil, nil, 0.1)
      begin
        l2.accept_nonblock.close
        taken += 1
      rescue IO::WaitReadable
      rescue => e
        others << e.class.name
      end
    end
    w.puts "#{taken} #{others.uniq.sort.join(',')}"
    exit!(0)
  end
end
w.close
120.times { TCPSocket.new("127.0.0.1", port2).close; sleep 0.002 }
kids.each { |k| Process.wait(k) }
answers = r.read.lines.map(&:split)
p answers.sum { |a| a[0].to_i }
p answers.flat_map { |a| a[1].to_s.split(",") }.uniq
