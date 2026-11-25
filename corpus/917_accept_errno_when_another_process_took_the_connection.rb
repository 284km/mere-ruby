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
