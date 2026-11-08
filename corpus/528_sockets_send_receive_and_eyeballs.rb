# What test/socket found: datagrams with recvmsg / sendmsg and the
# non-blocking forms, a bound datagram socket that connects keeps its port,
# ruby's own server helpers and Socket.tcp (Happy Eyeballs v2), and the
# smaller refusals.
require "socket"

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# a bound pair connected to each other, as test/socket's udp_pair
s1 = UDPSocket.new; s1.bind("127.0.0.1", 0)
s2 = UDPSocket.new; s2.bind("127.0.0.1", 0)
_, p1, _, a1 = s1.addr
_, p2, _, a2 = s2.addr
s1.connect(a2, p2); s2.connect(a1, p1)
show("still bound") { s1.addr[1] == p1 }
show("peer") { s1.peeraddr[1] == p2 }
show("nothing yet") { s1.recvfrom_nonblock(100, exception: false) }
s2.send("aaa", 0)
IO.select([s1])
show("recvfrom_nonblock") { m, a = s1.recvfrom_nonblock(100); [m, a[0], a[1] == p2] }
s2.send("b" * 100, 0)
IO.select([s1])
show("recvmsg truncated") { m, _, fl = s1.recvmsg(10); [m, fl & Socket::MSG_TRUNC == Socket::MSG_TRUNC] }
s2.sendmsg("ccc")
IO.select([s1])
show("sendmsg/recvmsg_nonblock") { m, ai, fl = s1.recvmsg_nonblock; [m, ai.class, fl] }
show("recvmsg_nonblock empty") { s1.recvmsg_nonblock(10, exception: false) }
show("recv_nonblock empty") { begin; s1.recv_nonblock(10); rescue IO::WaitReadable => e; e.class; end }
show("too long") { s2.send("\0" * 100_000, 0, "127.0.0.1", 7) }
[s1, s2].each(&:close)

# a datagram Socket sends to an address given
a = Socket.new(:INET, :DGRAM); a.bind(Socket.sockaddr_in(0, "127.0.0.1"))
b = Socket.new(:INET, :DGRAM)
b.send("x", 0, a.getsockname)
IO.select([a])
show("Socket recvfrom") { m, ai = a.recvfrom(10); [m, ai.class] }
[a, b].each(&:close)

# connect_nonblock twice keeps the first connection (the second's answer --
# 0, or EALREADY while the first is in progress -- depends on timing)
serv = Socket.new(:INET, :STREAM); serv.bind(Socket.sockaddr_in(0, "127.0.0.1")); serv.listen(5)
c = Socket.new(:INET, :STREAM)
c.connect_nonblock(serv.getsockname, exception: false)
IO.select(nil, [c], nil, 5)
begin
  c.connect_nonblock(serv.getsockname, exception: false)
rescue SystemCallError
end
s, sa = serv.accept
show("same connection") { Socket.unpack_sockaddr_in(c.getsockname) == Socket.unpack_sockaddr_in(sa) }
[serv, c, s].each(&:close)

# ruby's server helpers
show("tcp_server_sockets") do
  Socket.tcp_server_sockets("127.0.0.1", 0) { |socks| [socks.size, socks.map { |x| x.local_address.ip_port }.uniq.size] }
end

# Socket.tcp resolves each family on its own (Happy Eyeballs v2)
srv = TCPServer.new("127.0.0.1", 0)
port = srv.addr[1]
th = Thread.new { srv.accept }
class << Addrinfo
  alias __orig_getaddrinfo getaddrinfo
  def getaddrinfo(host, port, family = nil, *rest, **kw)
    return [] if family == Socket::AF_INET6 && host == "dual.example"
    return [Addrinfo.tcp("127.0.0.1", port)] if host == "dual.example"
    __orig_getaddrinfo(host, port, family, *rest, **kw)
  end
end
show("Socket.tcp") { Socket.tcp("dual.example", port) { |x| x.remote_address.ip_address } }
th.value.close
srv.close
show("tcp_fast_fallback") { Socket.tcp_fast_fallback }

# the smaller ones
show("pair block") { Socket.pair(:UNIX, :STREAM) { |x, y| [x.class, y.class, :rv] } }
show("unix pair block") { UNIXSocket.pair { |x, y| [x.class, y.class] } }
show("NUL in a host") { Addrinfo.ip("127.0.0.1\0x") }
show("NUL in a path") { UNIXSocket.open("/tmp/x\0") }
show("getnameinfo Addrinfo") { Socket.getnameinfo(Addrinfo.udp("127.0.0.1", 8888), Socket::NI_NUMERICHOST | Socket::NI_NUMERICSERV) }
show("multicast ttl") { o = Socket::Option.ipv4_multicast_ttl(128); [o.inspect, o.ipv4_multicast_ttl] }
show("for_fd -1") { BasicSocket.for_fd(-1) }
show("getpeereid") do
  x, y = UNIXSocket.pair
  r = x.getpeereid == [Process.euid, Process.egid]
  x.close; y.close
  r
end

# a stream closed while another thread waits on it: that thread's wait is
# the IOError (the pair's block, which was ignored, runs now)
show("closed under a waiter") do
  Socket.pair(:UNIX, :STREAM) do |i, o|
    t = Thread.new { Thread.current.report_on_exception = false; i.wait_readable }
    Thread.pass until t.status == "sleep"
    i.close
    begin
      t.join
      :no_error
    rescue IOError => e
      e.class
    end
  end
end
