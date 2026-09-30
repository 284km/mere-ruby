# A listener is on the address it was asked for, and #addr is the kernel's own
# getsockname(2): TCPServer.new("127.0.0.1", 0) is not a listener on every
# interface. A bind the kernel refuses is the Errno it named (the port in use,
# an address this host does not have, a socket bound twice), and a connection
# the peer RESET reads as Errno::ECONNRESET -- not as an end of file -- with the
# next write Errno::EPIPE. The peer runs in a thread. Only stable values are
# printed: no ports and no descriptor numbers.
require "socket"

s = TCPServer.new("127.0.0.1", 0)
port = s.addr[1]
p [s.addr[0], s.addr[2], s.addr[3], port > 0]
p [s.local_address.ip_address, s.local_address.ip_port == port]

# the same port again, and an address that is not here (TEST-NET-1)
begin
  TCPServer.new("127.0.0.1", port)
rescue SystemCallError => e
  p [e.class, e.message.sub(/port \d+/, "port N")]
end
begin
  TCPServer.new("192.0.2.1", 0)
rescue SystemCallError => e
  p [e.class, e.message]
end

# a name: the listener is on the name's first address, and a client that asks
# for the same name reaches it
l = TCPServer.new("localhost", 0)
c = TCPSocket.new("localhost", l.addr[1])
a = l.accept
p [l.addr[3] == l.local_address.ip_address, c.remote_address.ip_address == l.addr[3]]
p [a.peeraddr[1] == c.addr[1], a.addr[1] == l.addr[1], c.peeraddr[0] == l.addr[0]]
[a, c, l].each(&:close)

# Socket#bind is bind(2), once
sock = Socket.new(:INET, :STREAM)
sock.bind(Addrinfo.tcp("127.0.0.1", 0))
p sock.local_address.ip_address
begin
  sock.bind(Addrinfo.tcp("127.0.0.1", 0))
rescue SystemCallError => e
  p e.class
end
sock.listen(5)
c2 = TCPSocket.new("127.0.0.1", sock.local_address.ip_port)
a2, from = sock.accept
p [from.ip_port == c2.addr[1], a2.remote_address.ip_address]
[a2, c2, sock].each(&:close)

# a peer that closes with an unread byte in its buffer resets the connection
t = Thread.new do
  conn = s.accept
  IO.select([conn])
  conn.close
end
client = TCPSocket.new("127.0.0.1", port)
client.write "x"
t.join
p((client.read(1) rescue $!.class))
p((client.write("y") rescue $!.class))
client.close

# a datagram socket binds too, and a connected one reaches it
u = UDPSocket.new
u.bind("127.0.0.1", 0)
v = UDPSocket.new
v.connect("127.0.0.1", u.addr[1])
v.send("hello", 0)
p [u.addr[3], u.recv(10)]
[u, v, s].each(&:close)

# ...and a pipe with no reader is still EPIPE
r, w = IO.pipe
r.close
p((w.write("z") rescue $!.class))
